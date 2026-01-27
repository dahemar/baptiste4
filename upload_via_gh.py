#!/usr/bin/env python3
import os, sys, subprocess, json, base64
from urllib.parse import quote

ROOT='.'
REPO='dahemar/baptiste2'

def gh_get(path):
    cmd=['gh','api',f'/repos/{REPO}/contents/{path}']
    p=subprocess.run(cmd, capture_output=True, text=True)
    return p

def gh_put(path, message, content_b64, sha=None):
    cmd=['gh','api','--method','PUT',f'/repos/{REPO}/contents/{path}','-f',f'message={message}','-f',f'content={content_b64}']
    if sha:
        cmd.extend(['-f',f'sha={sha}'])
    p=subprocess.run(cmd, capture_output=True, text=True)
    return p

errors=0
success=0
for dirpath, dirnames, filenames in os.walk(ROOT):
    # skip .git
    if '.git' in dirpath.split(os.sep):
        continue
    for fname in filenames:
        fp=os.path.join(dirpath,fname)
        # skip script itself
        if fp==os.path.abspath(__file__):
            continue
        rel=os.path.relpath(fp, ROOT)
        # normalize path for API
        api_path=quote(rel)
        try:
            with open(fp,'rb') as f:
                data=f.read()
        except Exception as e:
            print(f"[ERROR] read {rel}: {e}")
            errors+=1
            continue
        content_b64=base64.b64encode(data).decode()
        # check existing
        p=gh_get(api_path)
        sha=None
        if p.returncode==0:
            try:
                obj=json.loads(p.stdout)
                if 'sha' in obj:
                    sha=obj['sha']
            except Exception:
                sha=None
        # perform put
        msg=f"chore: add {rel} via API"
        q=gh_put(api_path, msg, content_b64, sha)
        if q.returncode==0:
            print(f"[OK] {rel}")
            success+=1
        else:
            print(f"[FAIL] {rel} -> {q.stderr.strip()}")
            errors+=1

print(f"Done. success={success} errors={errors}")
if errors>0:
    sys.exit(2)
else:
    sys.exit(0)
