FROM php:7-apache-buster as base

ARG DEBIAN_FRONTEND=noninteractive

# edit this to use a different version of Saxon
ARG saxon='libsaxon-HEC-setup64-v1.2.1'

ARG jdk='openjdk-11-jdk-headless'

ARG jvm='/usr/lib/jvm/java-11-openjdk-amd64'

# needed for default-jre-headless
RUN mkdir -p /usr/share/man/man1

## dependencies
RUN apt-get update
RUN apt-get install -y --no-install-recommends ${jdk} unzip libxml-commons-resolver1.1-java

## fetch
RUN curl https://www.saxonica.com/saxon-c/${saxon}.zip --output saxon.zip
RUN unzip saxon.zip -d saxon

## install
RUN saxon/${saxon} -batch -dest /opt/saxon

## patch
COPY patches/php7_saxon.cpp /opt/saxon/Saxon.C.API/

## prepare
RUN ln -s /opt/saxon/libsaxonhec.so /usr/lib/
RUN ln -s /opt/saxon/rt /usr/lib/

## build
WORKDIR /opt/saxon/Saxon.C.API
RUN phpize
RUN ./configure --enable-saxon CPPFLAGS="-I${jvm}/include -I${jvm}/include/linux"
RUN make
RUN make install
RUN echo 'extension=saxon.so' > "$PHP_INI_DIR/conf.d/saxon.ini"
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# build the Schematron XSL files from the Schematron source files
FROM base AS builder

WORKDIR /build
COPY build ./

# Get JATS4R schemas...
ARG JATS4R_SCHEMATRONS_VERSION=0.0.4
RUN curl -L https://github.com/JATS4R/jats-schematrons/archive/v${JATS4R_SCHEMATRONS_VERSION}.tar.gz | tar xz
RUN php generate-xsl.php jats-schematrons-${JATS4R_SCHEMATRONS_VERSION}/schematrons/1.0/jats4r.sch jats4r.xsl

# Get eLife specific schemas...
ARG SCHEMATRONS_COMMIT=6f9a349e90a379037fa7086fa5c3cb1cc770c6c8
RUN curl -L https://github.com/elifesciences/eLife-JATS-schematron/raw/${SCHEMATRONS_COMMIT}/src/pre-JATS-schematron.sch -o elife-schematron-pre.sch
RUN php generate-xsl.php elife-schematron-pre.sch elife-pre.xsl
RUN curl -L https://github.com/elifesciences/eLife-JATS-schematron/raw/${SCHEMATRONS_COMMIT}/src/final-JATS-schematron.sch -o elife-schematron-final.sch
RUN php generate-xsl.php elife-schematron-final.sch elife-final.xsl

# fetch the DTDs and copy the Schematron XSL files into place
FROM base

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

COPY cli/ ./
COPY web/ ./
COPY functions/ ../functions/
COPY --from=builder /build/*.xsl ./

