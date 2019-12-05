# build the Schematron XSL files from the Schematron source files
FROM hubdock/php7-apache-saxonhe:1.1.2 AS builder

WORKDIR /build
COPY build ./

# Get JATS4R schemas...
ARG JATS4R_SCHEMATRONS_VERSION=0.0.4
RUN curl -L https://github.com/JATS4R/jats-schematrons/archive/v${JATS4R_SCHEMATRONS_VERSION}.tar.gz | tar xz
RUN php generate-xsl.php jats-schematrons-${JATS4R_SCHEMATRONS_VERSION}/schematrons/1.0/jats4r.sch jats4r.xsl

# Get eLife specific schemas...
ARG SCHEMATRONS_COMMIT=master
RUN curl -L https://github.com/elifesciences/eLife-JATS-schematron/raw/${SCHEMATRONS_COMMIT}/src/pre-JATS-schematron.sch -o elife-schematron-pre.sch
RUN php generate-xsl.php elife-schematron-pre.sch elife-pre.xsl
RUN curl -L https://github.com/elifesciences/eLife-JATS-schematron/raw/${SCHEMATRONS_COMMIT}/src/final-JATS-schematron.sch -o elife-schematron-final.sch
RUN php generate-xsl.php elife-schematron-final.sch elife-final.xsl

# fetch the DTDs and copy the Schematron XSL files into place
FROM hubdock/php7-apache-saxonhe

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
