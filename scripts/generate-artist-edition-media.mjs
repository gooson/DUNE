#!/usr/bin/env node
// Build the native, art-only movies from the approved theme map. No npm packages required.
// node scripts/generate-artist-edition-media.mjs [AppTheme raw values...]
// ffmpeg must be on PATH; set CHROME_BIN to use a different Chromium binary.
import assert from "node:assert/strict";
import { execFileSync, spawn } from "node:child_process";
import { once } from "node:events";
import { copyFile, mkdir, mkdtemp, rename, rm } from "node:fs/promises";
import { randomUUID } from "node:crypto";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const repository = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const source = join(
  repository,
  "docs/design/theme-map/themes/artist-editions.html",
);
const target = join(repository, "DUNE/Resources/ArtistEditions");
const fps = 15;

// Pick a common clock near whole cycles of each painting's independent motions.
const editions = {
  desertWarm: ["dune", 24.4],
  oceanCool: ["ocean", 22.4],
  forestGreen: ["forest", 14],
  sakuraCalm: ["sakura", 6.2],
  arcticDawn: ["arctic", 13.8],
  solarPop: ["solar", 15.2],
  contourAtlas: ["contour", 14],
  waterLilies: ["water-lilies", 22.2],
  patisserie: ["patisserie", 12.8],
};

const names = process.argv.slice(2);
const selected = names.length ? names : Object.keys(editions);
for (const name of selected) {
  assert(Object.hasOwn(editions, name), "Unknown theme: " + name);
}
await mkdir(target, { recursive: true });
const temporary = await mkdtemp(join(tmpdir(), "dune-artist-render-"));
const chrome = process.env.CHROME_BIN ||
  (process.platform === "darwin"
    ? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    : "chromium");
const browser = spawn(chrome, [
  "--headless",
  "--disable-gpu",
  "--disable-background-networking",
  "--no-first-run",
  "--disable-extensions",
  "--force-color-profile=srgb",
  "--remote-debugging-pipe",
  "--user-data-dir=" + join(temporary, "chrome"),
], { stdio: ["ignore", "ignore", "ignore", "pipe", "pipe"] });
const pending = new Map();
let nextRequest = 0, partial = "";
browser.on("error", (error) => {
  for (const { reject } of pending.values()) reject(error);
});
browser.on("exit", (code) => {
  for (const { reject } of pending.values()) {
    reject(Error("Chromium exited: " + code));
  }
});
browser.stdio[4].on("data", (chunk) => {
  const messages = (partial + chunk.toString()).split("\0");
  partial = messages.pop();
  for (const text of messages) {
    const message = JSON.parse(text);
    const entry = pending.get(message.id);
    if (!entry) continue;
    pending.delete(message.id);
    if (message.error) entry.reject(Error(message.error.message));
    else entry.resolve(message.result);
  }
});
function command(method, params = {}, sessionId) {
  const id = ++nextRequest;
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    browser.stdio[3].write(
      JSON.stringify({ id, method, params, sessionId }) + "\0",
    );
  });
}

async function render() {
  const { targetId } = await command("Target.createTarget", {
    url: "about:blank",
  });
  const { sessionId } = await command("Target.attachToTarget", {
    targetId,
    flatten: true,
  });
  const call = (method, params) => command(method, params, sessionId);
  async function evaluate(expression) {
    const { result, exceptionDetails } = await call("Runtime.evaluate", {
      expression,
      returnByValue: true,
      awaitPromise: true,
    });
    if (exceptionDetails) {
      throw Error(
        exceptionDetails.exception?.description || exceptionDetails.text,
      );
    }
    return result.value;
  }
  await call("Emulation.setDeviceMetricsOverride", {
    width: 400,
    height: 160,
    deviceScaleFactor: 2.4,
    mobile: false,
  });
  await call("Page.navigate", {
    url: pathToFileURL(source).href + "?mode=light&view=all",
  });
  for (let attempt = 0; attempt < 100; attempt++) {
    if (
      await evaluate(
        'document.readyState === "complete" && typeof art === "function"',
      )
    ) break;
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  await evaluate(`(() => {
    document.body.replaceChildren();
    const style = document.createElement("style");
    style.textContent = ".native-plate{position:absolute;inset:0;isolation:isolate}.print{z-index:0}.print::after{content:none}";
    document.head.append(style);
    document.documentElement.dataset.play = "playing";
  })()`);

  for (const name of selected) {
    const [theme, seconds] = editions[name];
    const frameCount = Math.round(seconds * fps);
    const cycles = await evaluate(`(async () => {
      const id = ${JSON.stringify(theme)};
      const plate = document.createElement("div");
      plate.className = "native-plate";
      plate.dataset.theme = id;
      plate.style.cssText = styleFor(id);
      plate.innerHTML = art(id);
      document.body.replaceChildren(plate);
      const image = new Image();
      image.src = new URL(imageFor(id), document.baseURI);
      await image.decode();
      await new Promise(requestAnimationFrame);
      if (plate.textContent.trim() || document.body.children.length !== 1 ||
          getComputedStyle(plate.querySelector(".print"), "::after").content !== "none") {
        throw Error("The export must contain only the painting and its motion");
      }
      window.nativeClocks = plate.getAnimations({subtree:true}).map(animation => {
        animation.pause();
        const timing = animation.effect.getTiming();
        const alternate = timing.direction.startsWith("alternate");
        const period = timing.duration * (alternate ? 2 : 1);
        const cycles = Math.round(${seconds * 1000} / period);
        if (!cycles || Math.abs(cycles * period / ${
      seconds * 1000
    } - 1) > 0.08) {
          throw Error("New artwork timing needs a matching loop duration: " + animation.animationName);
        }
        return { animation, duration: cycles * period };
      });
      return window.nativeClocks.length;
    })()`);
    assert(cycles > 0, "Missing artwork animation for " + name);

    const movie = join(temporary, name + ".mp4");
    const poster = join(temporary, name + ".jpg");
    const encoder = spawn("ffmpeg", [
      "-hide_banner",
      "-loglevel",
      "error",
      "-y",
      "-f",
      "image2pipe",
      "-framerate",
      String(fps),
      "-vcodec",
      "png",
      "-i",
      "pipe:0",
      "-an",
      "-map_metadata",
      "-1",
      "-vf",
      "scale=out_color_matrix=bt709:out_range=tv,format=yuv420p,setparams=color_primaries=bt709:color_trc=iec61966-2-1:colorspace=bt709:range=limited",
      "-bsf:v",
      "h264_metadata=colour_primaries=1:transfer_characteristics=13:matrix_coefficients=1:video_full_range_flag=0",
      "-c:v",
      "libx264",
      "-preset",
      "medium",
      "-crf",
      "18",
      "-threads",
      "2",
      "-g",
      String(fps * 2),
      "-colorspace",
      "bt709",
      "-color_primaries",
      "bt709",
      "-color_trc",
      "iec61966-2-1",
      "-color_range",
      "tv",
      "-movflags",
      "+faststart+write_colr",
      movie,
    ], { stdio: ["pipe", "ignore", "inherit"] });
    const encoderClosed = once(encoder, "close");
    // Coordinate the phases at the loop boundary while retaining the original CSS paths,
    // easing, direction and deliberate negative delays of each layer.
    try {
      for (let frame = 0; frame < frameCount; frame++) {
        await evaluate(
          `nativeClocks.forEach(c => { c.animation.currentTime = c.duration * ${
            frame / frameCount
          }; })`,
        );
        const { data } = await call("Page.captureScreenshot", {
          format: "png",
          fromSurface: true,
        });
        if (!encoder.stdin.write(Buffer.from(data, "base64"))) {
          await once(encoder.stdin, "drain");
        }
      }
      encoder.stdin.end();
      const [code] = await encoderClosed;
      assert.equal(code, 0, "ffmpeg failed to encode " + name);
    } finally {
      if (encoder.exitCode === null) encoder.kill();
    }
    execFileSync("ffmpeg", [
      "-hide_banner",
      "-loglevel",
      "error",
      "-y",
      "-i",
      movie,
      "-frames:v",
      "1",
      "-vf",
      "scale=in_color_matrix=bt709:out_color_matrix=bt601:out_range=full",
      "-q:v",
      "2",
      "-pix_fmt",
      "yuvj444p",
      poster,
    ]);
    // Stage each completed file on the target volume, even when TMPDIR is elsewhere.
    for (const [file, extension] of [[movie, ".mp4"], [poster, ".jpg"]]) {
      const staged = join(target, "." + name + "-" + randomUUID());
      try {
        await copyFile(file, staged);
        await rename(staged, join(target, name + extension));
      } finally {
        await rm(staged, { force: true });
      }
    }
    console.log(name + " · " + frameCount + " frames · " + seconds + "s");
  }
}

try {
  await render();
} finally {
  const closed = browser.exitCode === null && browser.signalCode === null
    ? once(browser, "close")
    : null;
  browser.kill();
  if (closed) await closed;
  await rm(temporary, { recursive: true, force: true });
}
