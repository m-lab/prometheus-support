from grafanalib.core import *

dashboard = Dashboard(
  title='Frontend Stats2',
  refresh='',
  time=Time('now-12h', 'now'),
  rows=[
    Row(
      height=Pixels(500),
      panels=[
        Graph(
          title="Frontend QPS",
          dataSource='Prometheus',
          targets=[
            Target(
                expr='sum by(code) (rate(http_requests_total{container="prometheus"}[2m]))',
                legendFormat="{{code}}",
                refId='A',
            ),
          ],
          yAxes=[
            YAxis(format=OPS_FORMAT),
            YAxis(format=SHORT_FORMAT),
          ],
          legend=Legend(
              alignAsTable=True,
              rightSide=True,
          ),
        ),
        Graph(
          title="Handler latency",
          dataSource='Prometheus',
          targets=[
            Target(
              expr='sum by (handler) (rate(http_request_duration_microseconds{quantile="0.9"}[2m]))',
              legendFormat="{{handler}}",
              refId='A',
            ),
          ],
          yAxes=single_y_axis(format='µs'),
          legend=Legend(
              alignAsTable=True,
              rightSide=True,
          ),
        ),
      ],
    ),
  ],
).auto_panel_ids()
