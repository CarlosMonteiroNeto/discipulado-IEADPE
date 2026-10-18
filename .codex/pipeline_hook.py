"""Project adapter for the installed pipeline's closed scoped runner."""
import json,os,pathlib,re,shlex,sys
SCRIPTS=pathlib.Path(r'C:/Users/Carlos_Neto/.codex/skills/two-model-sdd-pipeline/scripts')
sys.path.insert(0,str(SCRIPTS))
import codex_policy

def decision(event,policy):
 try:
  if event.get('hook_event_name')!='PreToolUse':raise ValueError('Invalid hook event')
  if event.get('tool_name')=='Bash':
   command=event.get('tool_input',{}).get('command','')
   if not isinstance(command,str) or re.search(r'[\n\r;&|<>`]|\$\(|\$\{|\x00',command):raise ValueError('Shell syntax is forbidden')
   argv=shlex.split(command)
   if len(argv)>=5 and argv[0]=='bash' and pathlib.Path(argv[1]).resolve()==(SCRIPTS/'scoped-run').resolve():
    if policy.get('role')!='operator':raise ValueError('Only operator may run checks')
    codex_policy._policy_root(policy)
    candidates=[pathlib.Path(p).resolve().parent for p in policy['protected_paths'] if pathlib.Path(p).name=='plan.json']
    if pathlib.Path(argv[2]).resolve() not in candidates:raise ValueError('Wrong plan workspace')
    if argv[3]!=str(policy['task_id']):raise ValueError('Wrong task')
    if argv[4] not in {'red','test','analyze','format'}:raise ValueError('Unknown check mode')
    if argv[4] in {'analyze','format'} and len(argv)!=5:raise ValueError('Unexpected selectors')
    for selector in argv[5:]:
     p=pathlib.PurePosixPath(selector)
     if p.is_absolute() or '..' in p.parts or not selector.endswith('.dart'):raise ValueError('Invalid Dart test selector')
    return {'hookSpecificOutput':{'hookEventName':'PreToolUse','permissionDecision':'allow'}}
   if not argv or argv[0]!='Get-Content':raise ValueError('Use the closed scoped runner for checks')
  return codex_policy.check_tool_call(event,policy)
 except Exception as exc:
  return {'hookSpecificOutput':{'hookEventName':'PreToolUse','permissionDecision':'deny','permissionDecisionReason':str(exc)}}

def main():
 try:
  policy=json.loads(pathlib.Path(os.environ['PIPELINE_ROLE_POLICY']).read_text(encoding='utf-8'))
  result=decision(json.load(sys.stdin),policy)
 except Exception as exc:result={'hookSpecificOutput':{'hookEventName':'PreToolUse','permissionDecision':'deny','permissionDecisionReason':str(exc)}}
 print(json.dumps(result))
if __name__=='__main__':main()
