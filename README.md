# vnstat-metrics

perl script based on `vnstat-metrics.cgi` which listens on `5599` and returns metrics for prometheus from vnstat

## requirements

`cpan install HTTP::Daemon`

set `VNSTAT_METRICS_HOST` or it will default to localhost
