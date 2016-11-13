// for all images, find parent p and add class centeted
var imgs = document.getElementsByTagName("img");
for (var i = 0; i < imgs.length; i++) {
    imgs[i].parentNode.className = 'centered';
}
// for all iframes, find parent p and add class centeted

var iframes = document.getElementsByTagName("iframe");

for (var i = 0; i < iframes.length; i++) {

    if(iframes[i].parentNode.tagName == 'P'){

        iframes[i].parentNode.className = 'centered';

    }

}