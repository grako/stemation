// for all images, find parent p and add class centeted
var imgs = document.getElementsByTagName("img");
for (var i = 0; i < imgs.length; i++) {
    imgs[i].parentNode.className = 'centered';
}
