{
  buildPythonPackage,
  fetchPypi,
  setuptools,
  robotframework,
}:
buildPythonPackage rec {
  pname = "robotframework-pabot";
  version = "5.2.2";
  pyproject = true;
  src = fetchPypi {
    pname = "robotframework_pabot";
    inherit version;
    hash = "sha256-SXw9clUcdu2iECnfaijGsu0ifmPEqFEOHGoGkLnivpE=";
  };
  build-system = [setuptools];
  dependencies = [robotframework];
  pythonImportsCheck = ["pabot.pabot"];
}
