// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// Abstract class for building deterministic, repeatable gas reports. These can be checked in
// alongside changes to the
// contract code to track the impact of the changes on gas costs for important user actions. Inherit
// from this class,
// implement the abstract methods, and use the helpers when building the scenarios.
/// @dev This contract was copied from
/// https://github.com/withtally/stUNI/blob/7de3a6661af7079a768d1f707f0bc5bba38c4a4f/test/gas-reports/GasReport.sol.
abstract contract GasReport is Test {
  using stdJson for string;
  using Strings for uint256;

  // Tracks that the user has started a scenario.
  bool isScenarioActive;

  // The name of the scenario being run at a given time.
  string currentScenarioName;

  struct Result {
    string scenarioName;
    uint256 gasUsed;
  }

  // Array of strings of the scenario name concatenated with the gas executing it.
  string[] results;

  mapping(string scenarioName => bool completed) isCompletedScenario;

  // Implement this method to return the name of the report being generated. Used in determining the
  // report filename
  // and put in the report itself as well.
  function REPORT_NAME() public pure virtual returns (string memory);

  // Implement this method if there are certain global state variables you want to populate with
  // non-zero values first
  // before executing scenarios. This is useful in cases where the slot will almost always be
  // non-zero for real users,
  // for example, a global accumulator like `totalSupply` will never be zero for real user, but
  // would be in tests.
  function touchSlots() public virtual;

  // Implement this method with gas scenarios. Call `startScenario`, do setup tasks, call the method
  // you want to track
  // in the report, call `recordScenarioGasReport` _immediately_ after the call you want to track,
  // then call
  // `stopScenario`.
  function runScenarios() public virtual;

  // Call this to start a gas reporting scenario. Provide a unique string name.
  function startScenario(string memory _scenarioName)
    public
    inactiveScenario
    uniqueScenario(_scenarioName)
  {
    isScenarioActive = true;
    currentScenarioName = _scenarioName;
  }

  // Call this to end a reporting scenario, some time after calling `recordScenarioGasResult`.
  function stopScenario() public activeScenario completeScenario {
    isScenarioActive = false;
  }

  // User this in the same way you would use Forge's `makeAddr`. It will prepend the name you
  // provide to the active
  // scenario name so that stack traces will have useful names on addresses.
  function makeScenarioAddr(string memory _name) public activeScenario returns (address) {
    return makeAddr(string.concat(_name, " in '", currentScenarioName, "'"));
  }

  // Call this during an active scenario to record the result.
  function recordScenarioGasResult() public activeScenario incompleteScenario {
    VmSafe.Gas memory _gas = vm.lastCallGas();
    results.push(_serialize(Result(currentScenarioName, uint256(_gas.gasTotalUsed))));
    isCompletedScenario[currentScenarioName] = true;
  }

  function _serialize(Result memory _result) internal pure returns (string memory) {
    return string.concat(
      "{ \"scenarioName\": \"",
      _result.scenarioName,
      "\", \"gasUsed\": ",
      _result.gasUsed.toString(),
      " }"
    );
  }

  // Writes the scenarios record to a report json file based on the report name.
  function writeReport() public inactiveScenario {
    string memory _json = "top";
    string memory _path = string.concat("./test/gas-reports/", REPORT_NAME(), "-gas-report.json");
    string memory _name = string.concat(REPORT_NAME(), "GasReport");
    _json.serialize("generatedAt", vm.unixTime() / 1000);
    _json.serialize("reportName:", _name);
    _json = _json.serialize("results", results);
    _json.write(_path);
  }

  // The actual "test" that gets run by Foundry to generate the report.
  function test_GenerateGasReport() public {
    // Skip running report generation unless the user has explicitly asked to do so via env var.
    // Is there a better way to prevent this from running during a normal `forge test`?
    bool _writeReport = vm.envOr("WRITE_REPORT", false);
    vm.skip(!_writeReport);

    touchSlots();
    runScenarios();
    writeReport();
  }

  // Requires an active scenario.
  modifier activeScenario() {
    require(isScenarioActive, "Called a scenario helper without an active scenario");
    _;
  }

  // Requires no active scenario.
  modifier inactiveScenario() {
    require(!isScenarioActive, "You called a method that is disallowed during an active scenario");
    _;
  }

  // Requires a gas result for the active scenario has *not* been recorded.
  modifier uniqueScenario(string memory _scenarioName) {
    require(
      !isCompletedScenario[_scenarioName],
      string.concat("Scenario name is a duplicate: ", _scenarioName)
    );
    _;
  }

  // Requires a gas result for the active scenario has *not* been recorded.
  modifier incompleteScenario() {
    require(
      !isCompletedScenario[currentScenarioName],
      string.concat("Scenario is already completed: ", currentScenarioName)
    );
    _;
  }

  // Requires a gas a gas result for the active scenario *has* been recorded.
  modifier completeScenario() {
    require(
      isCompletedScenario[currentScenarioName],
      string.concat("Scenario gas result has not been recorded: ", currentScenarioName)
    );
    _;
  }
}
