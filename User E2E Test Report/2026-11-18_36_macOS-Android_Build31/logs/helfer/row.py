import sys,os
R="/Users/carpeasrael/NextCloud_int/mac_project_2/FamilyNexus/User E2E Test Report/2026-11-18_36_macOS-Android_Build31/Ergebnisse.tsv"
a=[x.replace('\t',' ').replace('\n',' ') for x in sys.argv[1:]]
assert len(a)==7,len(a)
new=not os.path.exists(R)
with open(R,'a',encoding='utf-8') as f:
    if new: f.write("ID\tGerät\tSchritt\tErwartet\tBeobachtet\tScreenshot\tWertung\n")
    f.write("\t".join(a)+"\n")
