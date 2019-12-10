FROM php:7.3.8-apache-buster as base

ARG DEBIAN_FRONTEND=noninteractive

# edit this to use a different version of Saxon
ARG saxon='libsaxon-HEC-setup64-v1.1.2'

ARG jdk='openjdk-11-jdk-headless'

ARG jvm='/usr/lib/jvm/java-11-openjdk-amd64'

# needed for default-jre-headless
RUN mkdir -p /usr/share/man/man1

# patches for catalog support
COPY patches /tmp/patches

RUN apt-get update \
    ## dependencies
    && apt-get install -y --no-install-recommends ${jdk} unzip wget libxml-commons-resolver1.1-java \
    ## fetch
    && wget https://www.saxonica.com/saxon-c/${saxon}.zip \
    && unzip ${saxon}.zip -d saxon \
    && rm ${saxon}.zip \
    ## install
    && saxon/${saxon} -batch -dest /opt/saxon \
    && rm -r saxon \
    ## prepare
    && ln -s /opt/saxon/libsaxonhec.so /usr/lib/ \
    && ln -s /opt/saxon/rt /usr/lib/ \
    && ln -s ${jvm}/include/linux/jni_md.h ${jvm}/include/ \
    ## build
    && cd /opt/saxon/Saxon.C.API \
    ## patches for catalog support
    && cp /tmp/patches/* ./ \
    && phpize \
    && ./configure --enable-saxon CPPFLAGS="-I${jvm}/include" \
    && make \
    && make install \
    && echo 'extension=saxon.so' > "$PHP_INI_DIR/conf.d/saxon.ini" \
    && rm -r /opt/saxon/Saxon.C.API \
    && mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
    ## clean
    && apt-get clean \
    && apt-get remove -y ${jdk} unzip wget \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/

# build the Schematron XSL files from the Schematron source files
FROM base AS builder

WORKDIR /build
COPY build ./

# Get JATS4R schemas...
ARG JATS4R_SCHEMATRONS_VERSION=0.0.4
RUN curl -L https://github.com/JATS4R/jats-schematrons/archive/v${JATS4R_SCHEMATRONS_VERSION}.tar.gz | tar xz
RUN php generate-xsl.php jats-schematrons-${JATS4R_SCHEMATRONS_VERSION}/schematrons/1.0/jats4r.sch jats4r.xsl

# Get eLife specific schemas...
ARG SCHEMATRONS_COMMIT=5b145f9358f4e9b9d42c014ac9a206a62b3bb962
RUN curl -L https://github.com/elifesciences/eLife-JATS-schematron/raw/${SCHEMATRONS_COMMIT}/src/pre-JATS-schematron.sch -o elife-schematron-pre.sch
RUN php generate-xsl.php elife-schematron-pre.sch elife-pre.xsl
RUN curl -L https://github.com/elifesciences/eLife-JATS-schematron/raw/${SCHEMATRONS_COMMIT}/src/final-JATS-schematron.sch -o elife-schematron-final.sch
RUN php generate-xsl.php elife-schematron-final.sch elife-final.xsl

# fetch the DTDs and copy the Schematron XSL files into place
FROM base

RUN apt-get update && apt-get install -y httpry

WORKDIR /dtds
ARG DTDS_VERSION=0.0.5
ENV DTDS_VERSION=${DTDS_VERSION}
RUN curl -L https://github.com/JATS4R/jats-dtds/archive/v${DTDS_VERSION}.tar.gz | tar xz
ENV XML_CATALOG_FILES=/dtds/jats-dtds-${DTDS_VERSION}/schema/catalog.xml

# Get included files...
WORKDIR /var/www/html

# Get eLife specific supporting files...
ARG SCHEMATRONS_COMMIT=master
RUN curl https://raw.githubusercontent.com/elifesciences/eLife-JATS-schematron/${SCHEMATRONS_COMMIT}/src/countries.xml -o countries.xml
RUN curl https://raw.githubusercontent.com/elifesciences/eLife-JATS-schematron/${SCHEMATRONS_COMMIT}/src/publisher-locations.xml -o publisher-locations.xml
RUN curl https://raw.githubusercontent.com/elifesciences/eLife-JATS-schematron/${SCHEMATRONS_COMMIT}/src/us-uk-list.xml -o us-uk-list.xml

COPY web/ ./
COPY --from=builder /build/*.xsl ./
