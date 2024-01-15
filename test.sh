#!/usr/bin/env bash

FAILURE=0

# Array of PostgreSQL versions for testing
PG_VERSIONS=(9.5 9.6 10 11 12 13 14 15)

# Stop any existing containers from previous test runs
test_down() {
    docker-compose -f test/docker-compose-pgauto.yml down
}

test_run() {
    VERSION=$1
    TARGET=$2

    # Delete any existing test PostgreSQL data
    if [ -d postgres-data ]; then
        echo "Removing old PostgreSQL data from test directory"
        sudo rm -rf postgres-data
    fi

    # Create the PostgreSQL database using a specific version of PostgreSQL
    docker-compose -f "docker-compose-pg${VERSION}.yml" run --rm server create_db

    # Start Redash normally, using an "autoupdate" version of PostgreSQL
    TARGET_TAG="${TARGET}-alpine3.18" docker-compose -f docker-compose-pgauto.yml up

    # Verify the PostgreSQL data files are now the target version
    PGVER=$(sudo cat postgres-data/PG_VERSION)
    if [ "$PGVER" != "${TARGET}" ]; then
        echo
        echo "****************************************************************************"
        echo "Automatic upgrade of PostgreSQL from version ${VERSION} to ${TARGET} FAILED!"
        echo "****************************************************************************"
        echo
        FAILURE=1
    else
        echo
        echo "*******************************************************************************"
        echo "Automatic upgrade of PostgreSQL from version ${VERSION} to ${TARGET} SUCCEEDED!"
        echo "*******************************************************************************"
        echo
    fi

    # Shut down containers from previous test runs
    docker-compose -f docker-compose-pgauto.yml down
}

# Shut down containers from previous test runs
test_down

# If the user gives a first argument of "down", then we exit
# after shutting down any running containers from previous test runs
if [ "$1" = "down" ]; then
    exit 0
fi

# Change into the test directory
cd test || exit 1

for version in "${PG_VERSIONS[@]}"; do
    # Only test if the version is less than the latest version
    if [[ $(echo "$version < $PGTARGET" | bc) -eq 1 ]]; then
        test_run "$version" "$PGTARGET"
    fi
done

# Check for failure
if [ "${FAILURE}" -ne 0 ]; then
    echo
    echo "FAILURE: Automatic upgrade of PostgreSQL failed in one of the tests. Please investigate."
    echo
    exit 1
else
    echo
    echo "SUCCESS: Automatic upgrade testing of PostgreSQL to all versions up to $LATEST_VERSION passed without issue."
    echo
fi
