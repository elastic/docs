# Air-Gapped Elastic Documentation #

## Build the container ##

1. Go [here](https://github.com/elastic/docs). Read the docs if desired.
2. Clone the repo:

    ```bash
    git clone https://github.com/elastic/docs.git
    ```

3. navigate to air_gapped:

    ```bash
    cd docs/air_gapped
    ```

4. Build the latest container:

    ```bash
    # ensure the build script is executable
    chmod +x build.sh

    # Build the container with latest docs
    source build.sh
    ```

    * Test, if desired:

        ```bash
        # ensure the test script is executable
        chmod +x test.sh

        # Quick and dirty build+run combo
        source test.sh
        ```

## How to run ##

1. Standard `docker run`:

    ```bash
    # Vanilla Docker - run prebuilt image
    docker run --rm --name elastic-docs --publish 8000:8000/tcp -d docker.elastic.co/docs-private/air_gapped
    ```

2. Docker-compose:

    ```bash
    docker-compose up -d
    ```

## How to Stop ##

1. If `docker run` used:

    ```bash
    docker stop elastic-docs
    ```

2. If `docker-compose`:

    ```bash
    docker-compose down
    ```

3. Visit [localhost:8000](localhost:8000), and enjoy...