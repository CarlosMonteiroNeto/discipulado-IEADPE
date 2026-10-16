"""Compile only production MainActivity and helpers against cached real Android/Flutter APIs.
This is a source compatibility check, not an APK build or device-save check.
"""
from pathlib import Path
import os, subprocess, zipfile
root=Path(__file__).resolve().parents[2]
cache=Path.home()/'.gradle/caches/modules-2/files-2.1'
out=root/'build/task14-native-compile'
classes=out/'classes';classes.mkdir(parents=True,exist_ok=True)
libs=out/'libs';libs.mkdir(exist_ok=True)
def jar(group,artifact,version):
 return next((cache/group/artifact/version).rglob('*.jar'))
compiler=[jar('org.jetbrains.kotlin',a,'2.4.0') for a in ['kotlin-compiler-embeddable','kotlin-build-tools-api','kotlin-stdlib','kotlin-script-runtime','kotlin-daemon-embeddable']]
compiler += [jar('org.jetbrains.kotlin','kotlin-reflect','1.6.10'),jar('org.jetbrains.kotlinx','kotlinx-coroutines-core-jvm','1.8.0')]
compiler+=list((cache/'org.jetbrains/annotations').rglob('*.jar'))
android=Path(os.environ['LOCALAPPDATA'])/'Android/sdk/platforms/android-36/android.jar'
api=[android,classes,jar('org.jetbrains.kotlin','kotlin-stdlib','2.4.0')]
api+=list((cache/'io.flutter/flutter_embedding_debug').rglob('*.jar'))
for group in cache.glob('androidx.*'):
 api+=list(group.rglob('*.jar'))
 for aar in group.rglob('*.aar'):
  with zipfile.ZipFile(aar) as z:
   if 'classes.jar' in z.namelist():
    target=libs/(aar.stem+'.jar');target.write_bytes(z.read('classes.jar'));api.append(target)
api+=list((cache/'org.jetbrains/annotations').rglob('*.jar'))
source=root/'android/app/src/main'
java=source/'java/br/org/ieadpe/ieadpe_converts'
subprocess.run(['javac','--release','17','-d',str(classes),str(java/'ExportWriter.java'),str(java/'PortugueseCollation.java')],check=True,timeout=90)
# Argument files avoid Windows command-line length limits; paths stay quoted.
args=['-no-stdlib','-no-reflect','-jvm-target','17','-classpath',os.pathsep.join(map(str,api)),'-d',str(classes),str(source/'kotlin/br/org/ieadpe/ieadpe_converts/MainActivity.kt')]
argfile=out/'kotlin.args';argfile.write_text('\n'.join('"'+a.replace('\\','/')+'"' for a in args),encoding='utf8')
run=subprocess.run(['java','-Xmx512m','-cp',os.pathsep.join(map(str,compiler)),'org.jetbrains.kotlin.cli.jvm.K2JVMCompiler','@'+str(argfile)],cwd=root,capture_output=True,text=True,encoding='utf8',timeout=120)
print(run.stdout);print(run.stderr)
if run.returncode:raise SystemExit(run.returncode)
print('PASS: production MainActivity, SAF channel and Java helpers compile against cached real Android36/Flutter APIs. Not APK/device runtime verification.')
