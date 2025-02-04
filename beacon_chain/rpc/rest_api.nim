# beacon_chain
# Copyright (c) 2018-2024 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at https://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at https://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.push raises: [].}

## The `rest_api` module is a server implementation for the common REST API for
## Ethereum found at https://ethereum.github.io/beacon-APIs/
## along with several Nimbus-specific extensions. It is used by the validator
## client as well as many community utilities.
## A corresponding client can be found in the
## `spec/eth2_apis/rest_beacon_client` module

import
  "."/[
    rest_utils,
    rest_beacon_api, rest_builder_api, rest_config_api, rest_debug_api,
    rest_event_api, rest_key_management_api, rest_light_client_api,
    rest_nimbus_api, rest_node_api, rest_validator_api, rest_rewards_api]

export
  rest_utils,
  rest_beacon_api, rest_builder_api, rest_config_api, rest_debug_api,
  rest_event_api, rest_key_management_api, rest_light_client_api,
  rest_nimbus_api, rest_node_api, rest_validator_api, rest_rewards_api
