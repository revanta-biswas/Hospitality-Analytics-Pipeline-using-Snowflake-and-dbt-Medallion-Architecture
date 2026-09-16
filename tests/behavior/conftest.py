"""pytest-bdd step discovery for tests/behavior/.

Step definitions live in tests/behavior/steps/ (common/behavior-spec.md
Section 4). Importing the module here registers its @given/@when/@then
decorators with pytest-bdd for every *.feature-backed test collected under
this directory, per the standard pytest-bdd conftest pattern. No package
(__init__.py) exists under tests/, so the steps module is loaded by path
rather than via a relative import.
"""
import sys
from pathlib import Path

_STEPS_DIR = Path(__file__).resolve().parent / "steps"
if str(_STEPS_DIR) not in sys.path:
    sys.path.insert(0, str(_STEPS_DIR))

from stage_credential_steps import *  # noqa: F401,F403,E402
