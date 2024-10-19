const {
    aceVimMap,
    mapkey,
    imap,
    imapkey,
    getClickableElements,
    vmapkey,
    map,
    unmap,
    cmap,
    addSearchAlias,
    removeSearchAlias,
    tabOpenLink,
    readText,
    Clipboard,
    Front,
    Hints,
    Visual,
    RUNTIME
} = api;

map('sl', 'Translate selected text with DeepL', function() {
    var selectedText = window.getSelection().toString();
    if (selectedText) {
        var deeplUrl = `https://www.deepl.com/translator#en/ru/${encodeURIComponent(selectedText)}`;
        window.open(deeplUrl, '_blank');
    } else {
        Front.showBanner('Please select text to translate');
    }
});
