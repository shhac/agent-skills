# Datadog Query Syntax Reference

## Log queries

Used by `logs search`, `logs tail`, `logs facets`, and `traces search`.

```
service:web-api                    # exact tag match
status:error                       # by log status (error, warn, info, debug)
host:web-1                         # by host
source:nginx                       # by log source
@http.method:POST                  # facet match (@ prefix for attributes)
@http.status_code:>500             # numeric comparison (>, >=, <, <=)
@duration:>1000000                 # works in trace search too (nanoseconds)
"connection timeout"               # free text (quoted for exact phrase)
service:web AND status:error       # boolean AND (implicit between terms)
status:(error OR warn)             # boolean OR
NOT service:internal               # boolean NOT
-service:internal                  # exclusion shorthand
service:web* host:prod-*           # wildcards
```

### Tips

- Start broad with `logs facets` to see which services/hosts/statuses have volume
- Then add filters to `logs search` to drill into specific results
- Combine multiple filters to narrow progressively: `service:web status:error @http.status_code:>500`

## Metric queries

Used by `metrics query`.

```
avg:system.cpu.user{host:web-1}                    # basic: aggregation:metric{filter}
sum:http.requests{env:prod} by {service}            # grouping: split by tag
max:system.disk.used{*}                             # all hosts
avg:app.request.duration{service:api,env:prod}      # multiple filters (AND-ed)
```

Aggregations: `avg`, `sum`, `min`, `max`, `count`.

## Trace queries

Traces use the same log query syntax but with APM-specific facets.

```bash
agent-dd traces search --query "service:web-api @duration:>1000000000" --from now-30m
agent-dd traces search --query "status:error" --service web-api
agent-dd traces search --service web-api    # all traces for a service
```

Duration is in **nanoseconds** (1s = 1,000,000,000ns).

Common facets: `service`, `resource_name`, `@duration`, `status`, `@http.status_code`.
