import sys,json,urllib.request,urllib.error
sec={}
for l in open("/Users/carpeasrael/NextCloud_int/mac_project_2/FamilyNexus/secure/Lauf_1118_G1.txt"):
    if "=" in l:
        k,v=l.rstrip("\n").split("=",1); sec[k]=v
key=sys.argv[2]; user=sys.argv[1]
S="https://matrix-synapse-3ues.srv1348446.hstgr.cloud"
d=json.dumps({"type":"m.login.password","identifier":{"type":"m.id.user","user":user},"password":sec[key],"initial_device_display_name":"curl-gegenprobe"}).encode()
r=urllib.request.Request(S+"/_matrix/client/v3/login",d,{"Content-Type":"application/json"})
try:
    resp=urllib.request.urlopen(r); j=json.load(resp); print(resp.status)
    t=j["access_token"]
    lo=urllib.request.Request(S+"/_matrix/client/v3/logout",b"{}",{"Content-Type":"application/json","Authorization":"Bearer "+t})
    print("logout",urllib.request.urlopen(lo).status)
except urllib.error.HTTPError as e:
    print(e.code, json.load(e).get("errcode"))
