from typing import Dict
import subprocess
import atexit
import tempfile
import subprocess
import time

session_folder = tempfile.TemporaryDirectory(prefix="remoteapps")

class Session:
    #SSH session with syncronous and background task running and control master set up
    pass

class Profile:

    nix_packages = Dict[str,str] #Dict of command and the nix package you can find it in. For auto setup of remote deps.


    def teardown(self, session):
        pass

class Waypipe(Profile):
    nix_packages = {
        "waypipe": "waypipe"
        }

    def remote(self, session):
        session.run(f"waypipe -s {session_folder}/waypipe.sock server")
        return

    def local(self):
        self.process = subprocess.Popen(["waypipe", "-s", f"{session_folder}/waypipe.sock", "client"])
        for i in range(20):
            if session_folder.name + "/waypipe.sock":
                break
            time.sleep(0.2)

        return f"-R {session_folder}/waypipe.sock:{session_folder}/waypipe.sock"

class X11Satellite(Profile):
    pass
