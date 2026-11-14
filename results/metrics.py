import json,urllib.request,urllib.parse,datetime as dt,sys
P="http://localhost:19090/api/v1/query"
def q(expr,t):
    u=P+"?"+urllib.parse.urlencode({"query":expr,"time":t})
    r=json.load(urllib.request.urlopen(u))["data"]["result"]
    return float(r[0]["value"][1]) if r else None
ph=[l.split() for l in open("results/run2/phases.log")]
ts=lambda s:dt.datetime.strptime(s,"%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=dt.timezone.utc).timestamp()
out={}
for i,(j,p,t) in enumerate(ph):
    if p not in("read","write","mixed"): continue
    end=ts(ph[i+1][2]); start=ts(t); w=int(end-start)-5; e=end-5
    C='{name=~".*'+j+'.*"}' if False else ''
    r={
     "cpu_cores":q(f'avg_over_time(rate(process_cpu_seconds_total{{jvm="{j}"}}[30s])[{w}s:5s])*2' if False else f'avg_over_time((sum(rate(container_cpu_usage_seconds_total{{name!="",name!~"cadvisor.*"}}[10s])))[{w}s:5s])',e),
     "rss_mb_avg":q(f'avg_over_time((sum(container_memory_rss{{name!="",name!~"cadvisor.*"}}))[{w}s:5s])/1048576',e),
     "rss_mb_max":q(f'max_over_time((sum(container_memory_rss{{name!="",name!~"cadvisor.*"}}))[{w}s:5s])/1048576',e),
     "heap_mb_avg":q(f'avg_over_time(sum(jvm_memory_used_bytes{{jvm="{j}",area="heap"}})[{w}s:5s])/1048576',e),
     "gc_pause_ms_per_s":q(f'sum(increase(jvm_gc_pause_seconds_sum{{jvm="{j}"}}[{w}s]))*1000/{w}',e),
     "gc_count":q(f'sum(increase(jvm_gc_pause_seconds_count{{jvm="{j}"}}[{w}s]))',e),
     "hikari_pending_avg":q(f'avg_over_time(sum(hikaricp_connections_pending{{jvm="{j}"}})[{w}s:5s])',e),
     "actuator_up":q(f'avg_over_time(up{{job="actuator"}}[{w}s])',e),
     "pg_tps":q(f'avg_over_time(sum(rate(pg_stat_database_xact_commit_total{{datname="notes"}}[10s]))[{w}s:5s])',e),
     "rps_last_min":q(f'sum(rate(k6_http_reqs_total{{jvm="{j}",mode="{p}"}}[60s]))',e),
     "rps_first_min":q(f'sum(rate(k6_http_reqs_total{{jvm="{j}",mode="{p}"}}[60s]))',start+65),
    }
    out[f"{j}/{p}"]={k:(round(v,2) if v is not None else None) for k,v in r.items()}
    print(j,p,out[f"{j}/{p}"])
json.dump(out,open("results/run2/metrics.json","w"),indent=1)
