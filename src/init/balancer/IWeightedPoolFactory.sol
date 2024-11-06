// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.0;

import { IERC20 } from "src/interfaces/IERC20.sol";
import { IRateProvider } from "./IRateProvider.sol";

interface IWeightedPoolFactory {
    /**
     * @notice Returns a JSON representation of the contract version containing name, version number and task ID.
     */
    function version() external view returns (string memory);

    /**
     * @notice Returns a JSON representation of the deployed pool version containing name, version number and task ID.
     *
     * @dev This is typically only useful in complex Pool deployment schemes, where multiple subsystems need to know
     * about each other. Note that this value will only be updated at factory creation time.
     */
    function getPoolVersion() external view returns (string memory);

    /**
     * @dev Deploys a new `WeightedPool`.
     */
    function create(
        string memory name,
        string memory symbol,
        IERC20[] memory tokens,
        uint256[] memory normalizedWeights,
        IRateProvider[] memory rateProviders,
        uint256 swapFeePercentage,
        address owner,
        bytes32 salt
    )
        external
        returns (address);
}
