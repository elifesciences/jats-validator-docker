## Docker

The Dockerfile uses the [Schematron skeleton](https://github.com/Schematron/stf/tree/master/iso-schematron-xslt2) to build an XSLT 2.0 file from an input Schematron file.

The Docker container runs an Apache web server listening on port 80, hosting a set of PHP endpoints that validate an input XML file against the appropriate JATS DTD, format the XML, and/or validate the XML against the Schematron rules using `SaxonProcessor`.

## Usage

1. Build the Docker image: `docker build . --tag jats-validator --no-cache`
2. Start the Docker container: `docker run --rm --p 4000:80 jats-validator`
3. Open <http://localhost:4000/> and choose a JATS XML file to validate.

## Updating to a newer version of the schematron

This is currently a somewhat minimal manual step, automation does need to be bought into it at somepoint but that should also align with improving the automated testing of the container.

1. Edit the 'Docker File', and update the value of SCHEMATRONS_COMMIT to the commit ref of the schematron files you want to use.
2. Build the container locally, and ensure that it works...

   ```
   docker build . --tag jats-validator --no-cache
   docker run --rm --p 4000:80 jats-validator
   ```

3. If everything is OK, commit the changes using the following as a template for the commit message.

   ```
   fix: update to latest version of elife's schematron files

   Updated to revision 6f9a349e90a379037fa7086fa5c3cb1cc770c6c8
   ```

4. Push the changes to remote

   Note here, that we need to push to 2 branches. Publishing to DockerHub only happens from the 'develop' branch, but it's good practice to ensure that all fixes are also on master.

   ```
   git push origin master
   git checkout develop
   git cherry-pick <commit ref of update on master>
   git push origin develop
   ```

5. Once the new container has been published, you can updated the deployement on Kubernetes via the jats-validator-docker-formula project.
