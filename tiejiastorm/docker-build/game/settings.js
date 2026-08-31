var DOSWASMSETTINGS = {
    CLOUDSAVEURL: "",
    DEFAULTIMG: "windows95.img",
    DEFAULTCD: "CD/Dark Front.cue"
}

var rando = Math.floor(Math.random() * Math.floor(100000));
var script = document.createElement('script');
script.src = 'script.js?v=' + rando;
document.getElementsByTagName('head')[0].appendChild(script);