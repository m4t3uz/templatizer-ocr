LIBTEMPLATIZER=-L"../templatizer/libtemplatizer/"
CFLAGS=$(shell pkg-config --cflags gio-2.0)
CPPFLAGS=-Wall -fPIC -ltesseract
LDFLAGS=--shared -fPIC -Wl,--no-as-needed $(LIBTEMPLATIZER)
# The following directory stores shared libraries
# and tmpl scripts.
INSTALL_PATH=/var/lib/templatizer/quick
PLUGINS=ocr.so files.so calendar.so money.so nslookup.so transcode.so
TEMPLATES=ocr.tmpl files.tmpl calendar.tmpl money.tmpl \
	product-page.tmpl nslookup.tmpl transcode.tmpl index.tmpl
TEMPLATES+=header.tmpl footer.tmpl scripts.tmpl css.tmpl
DATA_FILES=app-background.jpg favicon.png
DATA_DIRECTORIES=css/ js/
LOCALIZATION=local/pt_BR/LC_MESSAGES/nslookup.mo

all: $(PLUGINS) $(LOCALIZATION)

ocr.so: ocr.o
	g++ $(LDFLAGS) -o $@ $< -ltesseract

files.so: files.o
	gcc $(LDFLAGS) -o $@ $< $(shell pkg-config --libs gio-2.0)

calendar.so: calendar.o
	gcc $(LDFLAGS) -o $@ $< -lical

money.so: money.o
	gcc $(LDFLAGS) -o $@ $< -lcsv

nslookup.so: nslookup.o
	gcc $(LDFLAGS) -o $@ $< -ltemplatizer -lGeoIP

transcode.so: transcode.o
	gcc $(LDFLAGS) -o $@ $< -ltemplatizer -lavformat -lavcodec

install: $(PLUGINS) $(TEMPLATES) $(DATA_FILES) $(DATA_DIRECTORIES) $(LOCALIZATION)
	rm -fr $(INSTALL_PATH)
	mkdir -p $(INSTALL_PATH)
	cp $(TEMPLATES) $(INSTALL_PATH)
	install $(PLUGINS) $(INSTALL_PATH)
	cp $(DATA_FILES) $(INSTALL_PATH)
	cp -r $(DATA_DIRECTORIES) $(INSTALL_PATH)
	chown -R www-data:www-data $(INSTALL_PATH)
	chmod a=rx $(INSTALL_PATH)
	chmod 544 $(INSTALL_PATH)/*
	cp local/pt_BR/LC_MESSAGES/*.mo /usr/share/locale/pt_BR/LC_MESSAGES
	cp apache2/quick.conf /etc/apache2/conf-available/
	a2enconf quick
	service apache2 reload

clean:
	rm -f $(PLUGINS) *.o access.log
	rm -fr local

po/%.pot: %.c
	mkdir -p po
	xgettext --keyword=gettext --language=C --add-comments --sort-output -o $@ $<
	# do this for every supported language
	mkdir -p po/pt_BR/
	#msginit --no-translator -i $@ -l pt_BR -o po/pt_BR/nslookup.po

po/pt_BR/%.po: po/%.pot
	msgmerge --update $@ $<

local/pt_BR/LC_MESSAGES/%.mo: po/pt_BR/%.po
	mkdir -p local/pt_BR/LC_MESSAGES/
	msgfmt -o $@ $<

test: $(PLUGINS) $(LOCALIZATIO)
	LANG="pt_BR.UTF-8" REQUEST_METHOD="GET" PATH_TRANSLATED="$(shell pwd)/nslookup.tmpl" /usr/lib/cgi-bin/templatizer

.PHONY: clean install test
.PRECIOUS: po/%.pot po/pt_BR/%.po
