import dartpilot_tools
from dartpilot_tools import annotation, benchmark


def test_packages_import():
    assert dartpilot_tools.__version__
    assert benchmark.__doc__
    assert annotation.__doc__
