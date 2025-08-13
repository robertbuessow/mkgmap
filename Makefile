IN_DIR = in
WORK_DIR = work
OUT_DIR = out
STYLE_DIR = my-style
STYLE_FILES = $(wildcard $(STYLE_DIR)/*)
TYP_FILES = typ-files/20011.txt typ-files/sameOrder.txt

OSMOSIS_VERSION = 0.49.2
OSMOSIS = osmosis-$(OSMOSIS_VERSION)
SPLITTER = splitter-r654
MKGMAP = mkgmap-r4923

$(IN_DIR)/$(OSMOSIS).tar:
	wget --directory-prefix=$(IN_DIR) https://github.com/openstreetmap/osmosis/releases/download/$(OSMOSIS_VERSION)/$(OSMOSIS).tar

$(OSMOSIS): $(IN_DIR)/$(OSMOSIS).tar
	tar xf $(IN_DIR)/$(OSMOSIS).tar

$(IN_DIR)/$(SPLITTER).tar.gz:
	wget --directory-prefix=$(IN_DIR) https://www.mkgmap.org.uk/download/$(SPLITTER).tar.gz

$(SPLITTER)/splitter.jar: $(IN_DIR)/$(SPLITTER).tar.gz
	tar xzf $(IN_DIR)/$(SPLITTER).tar.gz
	touch $(SPLITTER)/splitter.jar

$(IN_DIR)/$(MKGMAP).tar.gz:
	wget --directory-prefix=$(IN_DIR) https://www.mkgmap.org.uk/download/$(MKGMAP).tar.gz

$(MKGMAP)/mkgmap.jar: $(IN_DIR)/$(MKGMAP).tar.gz
	tar xzf $(IN_DIR)/$(MKGMAP).tar.gz
	touch $(MKGMAP)/mkgmap.jar

$(IN_DIR)/%-latest.osm.pbf:
	wget --directory-prefix=$(IN_DIR) https://download.geofabrik.de/europe/$(notdir $@)

# Unused
$(WORK_DIR)/%-filtered.osm.pbf: $(IN_DIR)/%-latest.osm.pbf osmosis.args
	@cmd="sed s=INPUT=$<=g osmosis.args | xargs -J % $(OSMOSIS)/bin/osmosis % --write-pbf $@"; \
	echo $cmd; \
	$cmd

#$(WORK_DIR)/%/split: $(WORK_DIR)/%-filtered.osm.pbf $(SPLITTER) Makefile
$(WORK_DIR)/%/split: $(IN_DIR)/%-latest.osm.pbf $(SPLITTER)/splitter.jar
	java -jar $(SPLITTER)/splitter.jar --output-dir=$(dir $@) $<
	touch $(dir $@)/split

$(OUT_DIR)/%.img: $(WORK_DIR)/%/split my.cfg $(MKGMAP)/mkgmap.jar $(STYLE_FILES) $(TYP_FILES)
	country=`basename $@ .img`; \
	mkdir -p $(OUT_DIR); \
	cd $(WORK_DIR)/$$country; \
	java -Xms5g -Xmx10g -XX:+UseParallelGC -Dlog.config=../../logging.properties -jar ../../$(MKGMAP)/mkgmap.jar \
	    --style-file=../../$(STYLE_DIR) \
		--country-name=$$country \
		--read-config=../../my.cfg \
		--read-config=template.args \
		$(patsubst %,../../%,$(TYP_FILES)); \
	mv gmapsupp.img ../../$(OUT_DIR)/$$country.img

/Volumes/GARMIN/Garmin/%.img: out/%.img
	cp $< $@

clean:
	rm -rf $(WORK_DIR)
	rm -rf $(OUT_DIR)

cleanall: clean
	rm -rf $(IN_DIR)
	rm -rf $(SPLITTER)
	rm -rf $(MKGMAP)

.PHONY: clean cleanall
.PRECIOUS: $(wildcard $(IN_DIR)/*) $(SPLITTER)/splitter.jar $(MKGMAP)/mkgmap.jar
.PRECIOUS: $(WORK_DIR)/%/split
.PRECIOUS: $(OUT_DIR)/%.img
