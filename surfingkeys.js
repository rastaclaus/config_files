addSearchAlias('l', 'deepl', 'https://www.deepl.com/translator#en/ru/', 's', 'https://www.deepl.com/translator#en/ru/', function(response) {
    var res = JSON.parse(response.text);
    return res.map(function(r){
        return r.phrase;
    });
});
