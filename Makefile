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

# ISO 3166-1 alpha-3 country codes for middle Europe
COUNTRY_CODES = \
	austria:AUT:0043 \
	belgium:BEL:0032 \
	czechia:CZE:0420 \
	germany:DEU:0049 \
	france:FRA:0033 \
	italy:ITA:0039 \
	hungary:HUN:0036 \
	liechtenstein:LIE:0423 \
	luxembourg:LUX:0352 \
	netherlands:NLD:0031 \
	poland:POL:0048 \
	slovakia:SVK:0421 \
	slovenia:SVN:0386 \
	switzerland:CHE:0041

COUNTRIES = austria germany france italy liechtenstein switzerland

# Convert country name to ISO code
country_to_iso = $(word 2,$(subst :, ,$(filter $(1):%,$(COUNTRY_CODES))))

# Convert ISO code to country name
iso_to_country = $(word 1,$(subst :, ,$(filter %:$(1),$(COUNTRY_CODES))))

# Example usage:
%.foo:
	country=$(basename $@ .foo); \
	country3=$$(echo $(COUNTRY_CODES) | tr ' ' '\n' | sed -n "s/$$country:\(...\):..../\1/p"); \
	echo $$country3


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
	rm -f $@
	wget --directory-prefix=$(IN_DIR) https://download.geofabrik.de/europe/$(notdir $@)

$(WORK_DIR)/%-contour.osm.pbf:
	@country=$$(basename $@ -contour.osm.pbf); \
	country3=$$(echo $(COUNTRY_CODES) | tr ' ' '\n' | sed -n "s/$$country:\(...\):..../\1/p"); \
	$(MAKE) $(IN_DIR)/Hoehendaten_Freizeitkarte_$$country3.osm.pbf; \
	cp $(IN_DIR)/Hoehendaten_Freizeitkarte_$$country3.osm.pbf $@

Hoehendaten_Freizeitkarte_%.osm.pbf:
	wget --directory-prefix=$(IN_DIR) http://develop.freizeitkarte-osm.de/ele_20_100_500/$(notdir $@)

$(WORK_DIR)/switzerland/contour.osm.pbf: $(IN_DIR)/Hoehendaten_Freizeitkarte_CHE.osm.pbf
	@cp $< $@

# Unused
$(WORK_DIR)/%-filtered.osm.pbf: $(IN_DIR)/%-latest.osm.pbf osmosis.args
	@cmd="sed s=INPUT=$<=g osmosis.args | xargs -J % $(OSMOSIS)/bin/osmosis % --write-pbf $@"; \
	echo $cmd; \
	$cmd

#$(WORK_DIR)/%/split: $(WORK_DIR)/%-filtered.osm.pbf $(SPLITTER) Makefile
$(WORK_DIR)/%/split: $(IN_DIR)/%-latest.osm.pbf $(SPLITTER)/splitter.jar
	@country=$$(basename $$(dirname $@) | sed 's/osm-oa-//'); \
	country3=$$(echo $(COUNTRY_CODES) | tr ' ' '\n' | sed -n "s/$$country:\(...\):..../\1/p"); \
	dialcode=$$(echo $(COUNTRY_CODES) | tr ' ' '\n' | sed -n "s/$$country:...:\(....\)/\1/p"); \
	id="22$${dialcode}00"; \
	cmd="java -jar $(SPLITTER)/splitter.jar --mapid=$$id --output-dir=$(dir $@) $<"; \
	echo "$$cmd"; \
	$$cmd
	touch $(dir $@)/split

$(WORK_DIR)/%/split-contour: $(WORK_DIR)/%-contour.osm.pbf $(SPLITTER)/splitter.jar
	@country=$$(basename $$(dirname $@) | sed 's/osm-oa-//'); \
	country3=$$(echo $(COUNTRY_CODES) | tr ' ' '\n' | sed -n "s/$$country:\(...\):..../\1/p"); \
	dialcode=$$(echo $(COUNTRY_CODES) | tr ' ' '\n' | sed -n "s/$$country:...:\(....\)/\1/p"); \
	id="21$${dialcode}00"; \
	cmd="java -jar $(SPLITTER)/splitter.jar --mapid=$$id --output-dir=$(dir $@)/contour $<"; \
	echo "$$cmd"; \
	$$cmd
	touch $(dir $@)/split-contour

# id=$$(echo $$((20000000 + 0x$$(sha1 -s $$country | cut -c1-8) % 100000))); \

$(OUT_DIR)/osm-oa-%.img: $(WORK_DIR)/%/split $(WORK_DIR)/%/split-contour my.cfg $(MKGMAP)/mkgmap.jar $(STYLE_FILES) $(TYP_FILES)
	@mkdir -p $(OUT_DIR); \
	country=$$(basename $@ .img | sed 's/osm-oa-//'); \
	country3=$$(echo $(COUNTRY_CODES) | tr ' ' '\n' | sed -n "s/$$country:\(...\):..../\1/p"); \
	dialcode=$$(echo $(COUNTRY_CODES) | tr ' ' '\n' | sed -n "s/$$country:...:\(...\)/\1/p"); \
	id="20$${dialcode}00"; \
	fid=1$$dialcode; \
	cmd="cd $(WORK_DIR)/$$country; \
		java -Xms5g -Xmx16g -XX:+UseParallelGC -Dlog.config=../../logging.properties -jar ../../$(MKGMAP)/mkgmap.jar \
			--style-file=../../$(STYLE_DIR) \
			--read-config=../../my.cfg \
			--mapname=$$id \
			--country-name=$$country \
			--country-abbr=$$country3 \
			--family-id=$$fid \
			--family-name=OSM\ Outabout \
			--description=Outabout\ OSM\ $$country \
			--area-name=RB_A_OSM_$$country \
			--series-name=RB_S_OSM_$$country \
			--overview-mapname=RB_O_OSM_$$country \
			--overview-mapnumber=$$id \
			--read-config=template.args \
			--read-config=contour/template.args \
			$(patsubst %,../../%,$(TYP_FILES)) \
			"; \
	echo "($$cmd)"; \
	bash -c "$$cmd"; \
	mv $(WORK_DIR)/$$country/gmapsupp.img $(OUT_DIR)/osm-oa-$$country.img

all: $(foreach country,$(COUNTRIES),$(OUT_DIR)/osm-oa-$(country).img)

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
.PRECIOUS: $(WORK_DIR)/%/split $(WORK_DIR)/%/split-contour
.PRECIOUS: $(OUT_DIR)/%.img
