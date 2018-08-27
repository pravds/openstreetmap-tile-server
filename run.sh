#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "usage: <import|run>"
    echo "commands:"
    echo "    import: Set up the database and import /data.osm.pbf"
    echo "    run: Runs Apache and renderd to serve tiles at /tile/{z}/{x}/{y}.png"
    echo "environment variables:"
    echo "    THREADS: defines number of threads used for importing / tile rendering"
    exit 1
fi

if [ "$1" = "import" ]; then
    # Initialize PostgreSQL
    service postgresql start
    sudo -u postgres createuser renderer
    sudo -u postgres createdb -E UTF8 -O renderer gis
    sudo -u postgres psql -d gis -c "CREATE EXTENSION postgis;"
    sudo -u postgres psql -d gis -c "CREATE EXTENSION hstore;"
    sudo -u postgres psql -d gis -c "ALTER TABLE geometry_columns OWNER TO renderer;"
    sudo -u postgres psql -d gis -c "ALTER TABLE spatial_ref_sys OWNER TO renderer;"

    sudo -u postgres createdb -E UTF8 -O renderer india_boundaries
    sudo -u postgres psql -d india_boundaries -c "CREATE EXTENSION postgis;"
    sudo -u postgres psql -d india_boundaries -c "ALTER TABLE geometry_columns OWNER TO renderer;"

    wget -nv http://download.geofabrik.de/asia/india-latest.osm.pbf -O /india-latest.osm.pbf
    wget -nv http://download.geofabrik.de/asia/pakistan-latest.osm.pbf -O /pakistan-latest.osm.pbf
    wget -nv http://download.geofabrik.de/asia/china-latest.osm.pbf -O /china-latest.osm.pbf

    # Import data
    sudo -u renderer osm2pgsql -d gis --create --slim -G --hstore --tag-transform-script /home/renderer/src/openstreetmap-carto/openstreetmap-carto.lua -C 2048 --number-processes ${THREADS:-4} -S /home/renderer/src/openstreetmap-carto/openstreetmap-carto.style /india-latest.osm.pbf
    sudo -u renderer osm2pgsql -d gis --create --slim -G --hstore --tag-transform-script /home/renderer/src/openstreetmap-carto/openstreetmap-carto.lua -C 2048 --number-processes ${THREADS:-4} -S /home/renderer/src/openstreetmap-carto/openstreetmap-carto.style /pakistan-latest.osm.pbf
    sudo -u renderer osm2pgsql -d gis --create --slim -G --hstore --tag-transform-script /home/renderer/src/openstreetmap-carto/openstreetmap-carto.lua -C 2048 --number-processes ${THREADS:-4} -S /home/renderer/src/openstreetmap-carto/openstreetmap-carto.style /china-latest.osm.pbf
    sudo -u renderer osm2pgsql -d india_boundaries -cGs /india-claim-boundaries.osm.xml
    exit 0
fi

if [ "$1" = "run" ]; then
    # Initialize PostgreSQL and Apache
    service postgresql start
    service apache2 restart

    # Configure renderd threads
    sed -i -E "s/num_threads=[0-9]+/num_threads=${THREADS:-4}/g" /usr/local/etc/renderd.conf

    # Run
    sudo -u renderer renderd -f -c /usr/local/etc/renderd.conf

    exit 0
fi

echo "invalid command"
exit 1