"""pytest-bdd step-definition loader — imports every steps module so its
@given/@when/@then decorators register before any test_*.py collects scenarios.
"""
from steps.profile_secrets_steps import *  # noqa: F401,F403,E402
