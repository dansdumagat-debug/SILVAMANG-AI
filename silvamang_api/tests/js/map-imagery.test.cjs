const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
function setup() {
 const images=[]; const callbacks=[];
 const L={GridLayer:{extend: (methods)=>class {
  constructor(options){this.options=options;Object.assign(this,methods);}
  getTileSize(){return {x:256,y:256};} on(){}
 }},Util:{template:(url,c)=>url.replace(/\{(\w+)\}/g,(_,k)=>c[k])}};
 vm.runInNewContext(fs.readFileSync('resources/views/admin/partials/map-imagery.blade.php','utf8').replace(/<\/?script>/g,''),{
  L,Image:class {constructor(){this.style={};images.push(this);}},
  document:{createElement:()=>({style:{},appendChild(image){this.child=image;}})},
  setTimeout:()=>1,clearTimeout:()=>{}
 });
 const layer=L.silvaFallbackLayer('https://tiles/{z}/{y}/{x}',{maxZoom:24,maxNativeZoom:19});
 const tile=layer.createTile({z:19,x:101,y:203},(error)=>callbacks.push(error));
 return {images,tile,callbacks,layer};
}
test('missing detailed tile uses correctly cropped parent, then finishes once',()=>{
 const {images,tile,callbacks,layer}=setup();
 assert.equal(layer.options.maxZoom,24);
 assert.equal(images[0].src,'https://tiles/19/203/101?blankTile=false');
 images[0].onerror();
 assert.equal(images[1].src,'https://tiles/18/101/50?blankTile=false');
 assert.equal(images[1].style.left,'-256px');
 assert.equal(images[1].style.top,'-256px');
 assert.equal(images[1].style.width,'512px');
 images[1].onload(); images[0].onload();
 assert.equal(tile.child,images[1]); assert.deepEqual(callbacks,[null]);
});
test('native imagery is not enlarged and cancelled tiles cannot finish',()=>{
 const first=setup();first.images[0].onload();
 assert.equal(first.tile.child.style.width,'256px');
 const second=setup();const callback=second.images[0].onload;
 second.tile.cancelImagery();callback();assert.equal(second.callbacks.length,0);
});
test('unavailable imagery stops at zoom zero',()=>{
 const {images,callbacks}=setup();
 for(let i=0;i<20;i++) images[i].onerror();
 assert.equal(images.length,20);assert.equal(callbacks.length,1);assert.ok(callbacks[0]);
});
