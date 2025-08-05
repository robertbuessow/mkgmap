IN_DIR = in
WORK_DIR = work
OUT_DIR = out
STYLE_DIR = my-style
STYLE_FILES = $(wildcard $(STYLE_DIR)/*)
TYP_FILES = typ-files/mapnik.txt

SPLITTER = splitter-r654
MKGMAP = mkgmap-r4923

$(SPLITTER).tar.gz: 
	wget https://www.mkgmap.org.uk/download/$(SPLITTER).tar.gz

$(SPLITTER): $(SPLITTER).tar.gz
	tar xzf $(SPLITTER).tar.gz

$(MKGMAP).tar.gz: 
	wget https://www.mkgmap.org.uk/download/$(MKGMAP).tar.gz

$(MKGMAP): $(MKGMAP).tar.gz
	tar xzf $(MKGMAP).tar.gz

$(IN_DIR)/%-latest.osm.pbf:
	wget --directory-prefix=$(IN_DIR) https://download.geofabrik.de/europe/$(notdir $@)

$(WORK_DIR)/%/split: $(IN_DIR)/%-latest.osm.pbf $(SPLITTER)
	java -jar splitter-r654/splitter.jar --output-dir=$(dir $@) $<
	touch $(dir $@)/split

$(OUT_DIR)/%.img: $(WORK_DIR)/%/split my.cfg $(MKGMAP) $(STYLE_FILES) $(TYP_FILES) Makefile
	country=`basename $@ .img`; \
	mkdir -p $(OUT_DIR); \
	cd $(WORK_DIR)/$$country; \
	java -Xms5g -Xmx10g -XX:+UseParallelGC -jar ../../$(MKGMAP)/mkgmap.jar \
	    --style-file=../../$(STYLE_DIR) \
		--country-name=$$country \
		--read-config=../../my.cfg \
		--read-config=template.args \
		../../$(TYP_FILES); \
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

.PRECIOUS: $(IN_DIR)/%-latest.osm.pbf
.PRECIOUS: $(WORK_DIR)/%/split
.PRECIOUS: $(OUT_DIR)/%.img

