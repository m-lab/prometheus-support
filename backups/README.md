# Get an API key

The API key must have Admin privileges. You can allocate a new API key through
the grafana web interface: Context menu for your user -> API Keys -> Add new.

## Usage

To create a backup:
```
GRAFANA_HOST=http://<url>:3000 GRAFANA_API_KEY=<api-key> ./backup.sh <suddir>
```

To restore from a backup:
```
GRAFANA_HOST=http://<url>:3000 GRAFANA_API_KEY=<api-key> ./restore.sh <suddir>
```

Note: evidently, it's possible to define dashboards with values (e.g. axis
settings) that are rejected during the import. For example, floats for "min"
values in a logBase:2 chart.
```
2017/05/10 10:43:08 strconv.Atoi: parsing "0.0": invalid syntax
2017/05/10 10:43:08 strconv.Atoi: parsing "0.0": invalid syntax
2017/05/10 10:45:19 strconv.Atoi: parsing "1.0": invalid syntax
2017/05/10 10:45:19 strconv.Atoi: parsing "1.0": invalid syntax
2017/05/10 10:45:50 strconv.Atoi: parsing ".001": invalid syntax
2017/05/10 10:45:50 strconv.Atoi: parsing ".001": invalid syntax
```

Changing these values to ints allowed the import.
