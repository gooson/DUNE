const fs = require('fs');
const vm = require('vm');
// Pass a local copy of https://cdn.jsdelivr.net/npm/d3@7.9.0/dist/d3.min.js as argv[2].
if (!process.argv[2]) throw new Error('Usage: node running-map-artwork.cjs /path/to/d3.min.js [output.json]');
const box = {}; vm.runInNewContext(fs.readFileSync(process.argv[2],'utf8'), box);
const d3 = box.d3;
const folder = __dirname + '/';
const geo = JSON.parse(fs.readFileSync(folder+'running-map-seoul-forest.geojson'));
const route = JSON.parse(fs.readFileSync(folder+'running-map-route.json'));
const line = {type:'LineString',coordinates:route.coordinates};
const projection = d3.geoMercator().fitExtent([[28,22],[372,350]],line);
const path = d3.geoPath(projection).digits(2);
const escape = s=>s.replaceAll('&','&amp;').replaceAll('"','&quot;').replaceAll('<','&lt;');
let background = '';
for (const kind of ['park','water','road']) background+=`<g class="map-${kind}">`+geo.features.filter(f=>f.properties.kind===kind).map(f=>`<path d="${path(f)}"/>`).join('')+'</g>';
let dist=[0];
for(let i=1;i<route.coordinates.length;i++)dist.push(dist[i-1]+d3.geoDistance(route.coordinates[i-1],route.coordinates[i])*6371008.8);
function portion(start,end){const points=route.coordinates.filter((p,i)=>dist[i]>=start&&dist[i]<=end);return points.length>1?path({type:'LineString',coordinates:points}):'';}
const total=dist.at(-1);
const trim=300;
const arrows=[];
for(const frac of [.18,.40,.66,.84]){
 const idx=dist.findIndex(d=>d>=total*frac);const a=projection(route.coordinates[idx-1]),b=projection(route.coordinates[idx]);
 const angle=Math.atan2(b[1]-a[1],b[0]-a[0])*180/Math.PI;
 arrows.push({x:b[0],y:b[1],angle});
}
const start=projection(route.coordinates[0]),end=projection(route.coordinates.at(-1));
const markers=[.15,.34,.53,.71,.91].map((f,i)=>{let idx=dist.findIndex(d=>d>=total*f);let p=projection(route.coordinates[idx]);return {x:p[0],y:p[1],label:String(i+1)}});
const virtualEnd=projection(route.coordinates[dist.findIndex(d=>d>=total*.628)]);
const venues=JSON.parse(fs.readFileSync(folder+'running-map-venues.json')).map(v=>({...v,point:projection(v.coordinate)}));
const result={venues,virtualEnd,virtualProgress:portion(0,total*.628),background,route:path(line),trimmed:portion(trim,total-trim),arrows,start,end,markers,segments:[0,1,2,3,4,5].map(i=>portion(total*i/6,total*(i+1)/6)),trimmedSegments:[0,1,2,3,4,5].map(i=>portion(Math.max(trim,total*i/6),Math.min(total-trim,total*(i+1)/6)))};
fs.writeFileSync(process.argv[3] || '/private/tmp/dune-map-artwork.json',JSON.stringify(result));
console.log(JSON.stringify({backgroundBytes:background.length,routeBytes:result.route.length,distance:total,routeBounds:d3.geoBounds(line)}));
