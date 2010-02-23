so_ext_all.obo:
	obo-cat.pl so-xp.obo so_ext.obo interval_relations.obo > $@

so_all.obo:
	obo-cat.pl so-xp.obo interval_relations.obo > $@

%.owl: %.obo
	go2owl $< > $@

deploy:
	scp so_all.owl $(LOC)/so_ext_all

