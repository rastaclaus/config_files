Front.registerInlineQuery({
	url: `https://translate.yandex.net/api/v1.5/tr.json/translate
				?key=trnsl.1.1.20171231T100146Z.4b564db549f21328.24eefc55e8411dd6a39d453dcec3d14eddd2844b
				&lang=ru
				&text=`,
	parseResult: function(res) {
		try {
			res = JSON.parse(res.text);
			return res.text;
		} catch (e) {
			return e;
		}
	}
});

