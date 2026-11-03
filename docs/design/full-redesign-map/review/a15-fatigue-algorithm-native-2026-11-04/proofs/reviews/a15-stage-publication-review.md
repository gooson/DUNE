# A15 independent stage publication review

**P1 = 0, P2 = 0, P3 = 0 confirmed** in this bounded stage and installer-source review. This clears the reviewed stage for the separately controlled installer; it does not itself install or publish.

Actual source `95ecbe1846133c1e5d1073e24686ee5fff72e549`
Stage inventory SHA-256 `8545b98da809c3a1a33cfbfe546882576104b87bae6ddde3a82ff5fc4e747885`
Builder SHA-256 `b997bb1e94bf6c9394f52a4a5bc35a41fb83ce54eb3906d40e4999ee07838deb`
Installer SHA-256 `ca9829944061c2a10eb65ee69aa3eeb130d7e7277ab403fc400ae0d69b3050e2`
Input SHA-256 `03ece95ddf0679faa2165106f7639efaf26bb4a7c6d0891436084f968a30281a`

- All 53 actual inventory files and hashes match: 19 allowed existing output paths and 34 new gallery files. No extra files or symlinks. All 366 validated input hashes, 19 baseline output hashes, eight source and three renderer pins match. Four normal, five MAX and five iPad legend-route PNG/AX pairs match their raw files, evidence.json and staged copies. The normal actual-map image is the same canonical capture.
- All four old before images equal existing A15 map assets; captions explicitly identify historical generic fatigue explanation and unknown individual source/device/pose. All non-A15 capture objects and embedded comparison evidence are unchanged. The 110-card tier pages have no non-A15 card changes. Board pixel differences are confined to the A15 tiles (regular 660,2032–913,2582; iPad 161,3507–457,3902; Duo 173,3507–444,3902; Duo-open 46,3519–572,3889), preserving A13/A14 and other screen pixels and metadata. All 952 local HTML references resolve against staged files and unchanged repository.
- All four canonical, five MAX and five A03 captions correspond to their real actions, including separate legend, formula/τ, dismissed map and Activity return. No nonexistent primary dismissal image is asserted. The actual same-source matrix comprises closed Duo normal+dark MAX 2/2, open Duo normal 1/1, phone normal 1/1, iPad normal 1/1 and iPad recovery-legend consumer 1/1. Representative MAX glyphs were visually inspected; passing all ten AX frame/label assertions does not mean all ten glyphs were inspected. No universal language, contrast, VoiceOver or data-state claim follows.
- Builder source binds actual per-archive source/selector, positive test nodes, real UID/runtime, creator ancestry, readiness, producer, pipeline time/log and paired Duo pose, and matches native evidence joins. No A14 failure history is imported as A15 history. Installer checks reviewed inventory/input/source/baselines, stages only its allowlist, creates the gallery exclusively, and retains backups for conditional rollback. This is static code review, not an exercised rollback or installation.

## Selected evidence hashes

| Capture | PNG SHA-256 | AX SHA-256 |
| --- | --- | --- |
| regular normal | f660b04b5c01b21c4c840a0fa263ad9850f4f303f44fca07440fee923f9e3299 | 1bdadd821a1ac9944a649110988a19c3df886cdd015ed8d9ed97e5dec520d999 |
| ipad normal | 64bafc2db931225a8b02b7ee1aefb4677f03bfb666ba908d105b3d993c096fad | 6cf354c13963a1fb8145ed21c9d6541bbf4e75a38b018af6b7059c98984b93db |
| duo normal | ede3a2265d4e3419a252cf816e22241222bb85f104fd6f44528f19696184064f | 3ebb681df4fa18c1cb565f1a53d163832a700824e6c8f400ba1623ff21c6864a |
| duo-open normal | 94ffe265a6193329e56a640be2bce53f9541d15f45d15b8ac1af2115864a0f73 | bffa822df95e4036611ac0dffbfc373c222023e4747a13be72de7e850ffbdb40 |
| A15 fatigue formula MAX | c0b2cb636ac61f5f04bbb67b886d45ad665643c53d2ddec5303ddbad1a40404f | 20c097746ec5ad287df2a897f617fb6201d1da90415bb6914bd5920e7effe0fb |
| A15 effective tau MAX | f9a0b96bfc0e11396b897ac6dd05dd6f9081137a730501b5bbdeaa1753eddaf1 | 131f7c2de6b4f948a670bb2bde41101edc558dae240b75836f868e51b2a53926 |
| A15 fatigue level 1 MAX MAX | da53dd93cf210d6b4afe48f15d6c0a03f2a04889e428f879eca7a57ce88ff604 | ccbf0d3ff664f5f47f2f77046cd91f22f24db273b4db5eeac75608947d4ce6b0 |
| A15 fatigue level 5 MAX MAX | da03e38857c9a50ab4d06fb58f216e6203dccd77749e0fbc7871fe80072b4997 | 9c5aa3b64928c0a008b3a4fb8df6a53519173e312c66eca63de6671b213862b6 |
| A15 fatigue level 10 MAX MAX | c61a4f7c9b8c3313f94d2c22e8f1172a6b5c14eba5cf04ed5eefd9b8bf4a6e2f | ed69dadd66c4900bbbc66c4589922e5c70000659bea34ff16eaddb63f3f4a6ba |
| A15 A03 recovery legend | 3788e18df4e335da7c996b29d25c67203ead9ef7c6a24cb97136021278d24ed6 | aab1d391af51a6afa0808652f9fe8de1368ab65595cc1a44a55a8d5e8c82d091 |
| A15 A03 fatigue formula | 3915b0bbfceb04516f4b8a79b483dd0676495f89208c3c8c24c5d647fc45d481 | ec360e269e1e254113c0763a628bc7d1edb5d9be0235147f2b0d5046deb30377 |
| A15 A03 effective tau | 3915b0bbfceb04516f4b8a79b483dd0676495f89208c3c8c24c5d647fc45d481 | 40b513eec7bbd73845b7cee8bfe95d02933860d8044fa756fa0408d42eecc55d |
| A15 A03 fatigue dismissed | 3788e18df4e335da7c996b29d25c67203ead9ef7c6a24cb97136021278d24ed6 | e6ea505e7bac3719bc3f5927a077de725642c1d7f85017bc8cf996fb2adb5a73 |
| A15 A03 returned to Activity | dff0394006674190593fcf95a1b0fba9429132f17f3efd54f6f9e017b1a53ddb | 74a0868c192830c3bb1eea64bde92a83e588aaeddd76873ce88c953d1f21f919 |

No build, tests, device, source/repository edit or installation was performed.
