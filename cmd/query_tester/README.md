# Query Tester

Query tester uses an undocumented and unofficially supported language used
within the prometheus source for testing queryies.

There is some desire to generalize this language and make it officially
supported, but until then, we are borrowing what is currently available to get
as close as we can.

## Test format

The `promql.Test` uses a special purpose syntax for setting up data available
for a test query, and specifying expected results.

The basic form is:
```
clear
load <step>
    <metric_name>{<label>=<value>, ...} <values>

eval instant at <eval-time> <promql query under test>
    <expected result metrics>
```

For example:
```
clear
load 1m
    metric_name{service="unrelated-service"} 1

eval instant at 0m absent(up{service="ssh806"})
    {service="ssh806"} 1
```

* `clear` resets the current data set.

* `load` reads in a set of metrics and sets values for those metrics. The load
   parameter is a step size, in the same form as supported by
   `time.ParseDuration`, e.g. 1m for 1 minute.

* `eval instant at 0m` evaluates an instantaneous query expression evaluated at
  time 0. Timestamps begin at 0. NOTE: While some queryies may be very long, for
  now, the entire expression must be on a single line.

## Advanced test format

When loading metric values, you may specify repeated values. For example:
```
clear
load 1m
    metric_name{service="unrelated-service"} 1 0 0 1 1 1
```

This saves values at corresponding times: 0m, 1m, 2m, 3m, 4m, 5m.


There is also an abreviated form that applies a delta to every step:
```
clear
load 1m
    metric_name{service="unrelated-service"} 0+10x20
```

The form is: `<initial value> [+-] <delta> x <number of steps>`

So, using the example, the initial value is 0, and for 20 steps, we'll add 10
each step. This will save values:
```
 0m, 0
 1m, 10
 2m, 20
 3m, 30
 4m, 40
 5m, 50
```
