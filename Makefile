
IN_DIR=in
WORK_DIR=work
OUT_DIR=out
SPLITTER=splitter-r654
MKGMAP=mkgmap-r4923

$(SPLITTER): 
	wget https://www.mkgmap.org.uk/download/$(SPLITTER).tar.gz
	tar xzf $(SPLITTER).tar.gz

$(MKGMAP): 
	wget https://www.mkgmap.org.uk/download/$(MKGMAP).tar.gz
	tar xzf $(MKGMAP).tar.gz

$(IN_DIR)/%-latest.osm.pbf:
	wget --directory-prefix=$(IN_DIR) https://download.geofabrik.de/europe/$(notdir $@)

$(WORK_DIR)/%/split: $(IN_DIR)/%-latest.osm.pbf $(SPLITTER)
	java -jar splitter-r654/splitter.jar --output-dir=$(dir $@) $<
	touch $(dir $@)/split

$(OUT_DIR)/%.img: $(WORK_DIR)/%/split my.cfg $(MKGMAP)
	country=`basename $@ .img`; \
	mkdir -p $(OUT_DIR); \
	cd $(WORK_DIR)/$$country; \
	java -Xms5g -Xmx10g -XX:+UseParallelGC -jar ../../$(MKGMAP)/mkgmap.jar \
		--read-config=../../my.cfg \
		--read-config=template.args \
		--country-name=$$country && \
	mv gmapsupp.img ../../$(OUT_DIR)/$$country.img


clean:
	rm -rf $(WORK_DIR)
	rm -rf $(OUT_DIR)

.PRECIOUS: $(IN_DIR)/%-latest.osm.pbf
.PRECIOUS: $(WORK_DIR)/%/split

