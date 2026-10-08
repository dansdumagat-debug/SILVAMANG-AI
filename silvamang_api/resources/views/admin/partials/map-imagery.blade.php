<script>
// Esri coverage varies by location. Request a real error instead of its grey
// placeholder, then crop the matching parent tile without changing pin positions.
L.silvaFallbackLayer = function (url, options) {
    const Imagery = L.GridLayer.extend({
        createTile: function (coords, done) {
            const tile = document.createElement('div');
            tile.style.overflow = 'hidden';
            tile.style.position = 'relative';
            const size = this.getTileSize();
            let finished = false;
            let activeImage;
            let timer;
            const finish = (error) => {
                if (finished) return;
                finished = true;
                clearTimeout(timer);
                done(error, tile);
            };
            const load = (zoom) => {
                if (finished) return;
                const scale = Math.pow(2, coords.z - zoom);
                const x = Math.floor(coords.x / scale);
                const y = Math.floor(coords.y / scale);
                const image = new Image();
                activeImage = image;
                image.alt = '';
                image.style.position = 'absolute';
                image.style.maxWidth = 'none';
                image.style.width = `${size.x * scale}px`;
                image.style.height = `${size.y * scale}px`;
                image.style.left = `${-(coords.x - x * scale) * size.x}px`;
                image.style.top = `${-(coords.y - y * scale) * size.y}px`;
                image.onload = () => {
                    if (finished || image !== activeImage) return;
                    tile.appendChild(image);
                    finish(null);
                };
                image.onerror = () => {
                    if (finished || image !== activeImage) return;
                    clearTimeout(timer);
                    if (zoom > 0) load(zoom - 1);
                    else finish(new Error('Map imagery could not be loaded.'));
                };
                timer = setTimeout(image.onerror, 8000);
                image.src = L.Util.template(url, { z: zoom, x, y }) + '?blankTile=false';
            };
            // Stop obsolete requests when the user pans or changes layers.
            tile.cancelImagery = () => {
                finished = true;
                clearTimeout(timer);
                if (activeImage) {
                    activeImage.onload = null;
                    activeImage.onerror = null;
                    activeImage.src = '';
                }
            };
            load(coords.z);
            return tile;
        },
    });
    const layer = new Imagery(options);
    layer.on('tileunload', (event) => event.tile.cancelImagery?.());
    return layer;
};
</script>
