#!/bin/bash
if [ "${1}" == "" ]; then
  echo "Please enter a gzipped database dump file"
  exit 1
fi
if [ ! -f ${1} ]; then
  echo "Dump file (${1}) does not exist!"
  exit 1
fi
dump=${1::-3}

read -s -p "Please enter the PostgreSQL password: " pgpass

echo "Step 1: Unzip ${1}"
gunzip ${1}
if [ ! -f ${dump} ]; then
  echo "file (${dump}) does not exist, did gunzip fail?"
  exit 1
fi
echo "Step 2: Correcting ${dump}"
sed -i -e 's/Owner\:\ db/Owner\:\ finetic/g' ${dump}
sed -i -e 's/OWNER\ TO\ db\;/OWNER\ TO\ finetic\;/g' ${dump}
echo "Step 3: Activate SSH tunnel"
ssh -f -T -M -N -S control-socket -L 127.0.0.1:5432:d5fc6fddc746.acc-db.postgres.database.azure.com:5432 dlp-acc.finetic.dev
ssh -S control-socket -O check dlp-acc.finetic.dev
echo "Step 4: Deleting tables"
PGPASSWORD=${pgpass} psql -h localhost -U finetic -d waimo -c "DO \$\$ DECLARE rec RECORD; BEGIN FOR rec IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP EXECUTE 'DROP TABLE IF EXISTS \"' || rec.tablename || '\" CASCADE'; END LOOP; END \$\$;"
echo "Step 5: Deleting sequences"
PGPASSWORD=${pgpass}psql -h localhost -U finetic -d waimo -c "DO \$\$ DECLARE rec RECORD; BEGIN FOR rec IN (SELECT sequencename FROM pg_sequences WHERE schemaname = 'public') LOOP EXECUTE 'DROP SEQUENCE IF EXISTS \"' || rec.sequencename || '\" CASCADE'; END LOOP; END \$\$;"
echo "Step 6: Restoring data"
PGPASSWORD=${pgpass}psql -h localhost -U finetic -d waimo < ${dump}
echo "Step 7: Close SSH tunnel"
ssh -S control-socket -O exit dlp-acc.fiinetic.dev
