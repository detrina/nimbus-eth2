# beacon_chain
# Copyright (c) 2018-2024 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at https://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at https://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.push raises: [].}

import std/[typetraits, strutils]
import results, stew/[assign2, base10, byteutils, endians2], presto/common,
       libp2p/peerid, serialization, json_serialization,
       json_serialization/std/[net, sets],
       json_serialization/stew/results as jsonSerializationResults,
       stint, chronicles
import ".."/[eth2_ssz_serialization, forks, keystore],
       ".."/../consensus_object_pools/block_pools_types,
       ".."/mev/[bellatrix_mev, capella_mev],
       ".."/../validators/slashing_protection_common,
       "."/[rest_types, rest_keymanager_types]
import nimcrypto/utils as ncrutils

export
  eth2_ssz_serialization, results, peerid, common, serialization, chronicles,
  json_serialization, net, sets, rest_types, slashing_protection_common,
  jsonSerializationResults, rest_keymanager_types

from web3/primitives import Hash32, Quantity
export primitives.Hash32, primitives.Quantity

func decodeMediaType*(
    contentType: Opt[ContentTypeData]): Result[MediaType, string] =
  if contentType.isNone or isWildCard(contentType.get.mediaType):
    return err("Missing or incorrect Content-Type")
  ok contentType.get.mediaType

type
  EmptyBody* = object

createJsonFlavor RestJson

RestJson.useDefaultSerializationFor(
  AttestationData,
  BLSToExecutionChange,
  BeaconBlockHeader,
  BlobSidecar,
  BlobSidecarInfoObject,
  BlobsBundle,
  Checkpoint,
  ConsolidationRequest,
  ContributionAndProof,
  DataEnclosedObject,
  DataMetaEnclosedObject,
  DataOptimisticAndFinalizedObject,
  DataOptimisticObject,
  DataRootEnclosedObject,
  DataVersionEnclosedObject,
  DeleteKeystoresBody,
  DeleteKeystoresResponse,
  DeleteRemoteKeystoresResponse,
  DenebSignedBlockContents,
  Deposit,
  DepositData,
  DepositRequest,
  DepositTreeSnapshot,
  DistributedKeystoreInfo,
  ElectraSignedBlockContents,
  EmptyBody,
  Eth1Data,
  EventBeaconBlockObject,
  ExecutionRequests,
  Fork,
  FuluSignedBlockContents,
  GetBlockAttestationsResponse,
  GetBlockHeaderResponse,
  GetBlockHeadersResponse,
  GetDepositContractResponse,
  GetDepositSnapshotResponse,
  GetDistributedKeystoresResponse,
  GetEpochCommitteesResponse,
  GetEpochSyncCommitteesResponse,
  GetForkChoiceResponse,
  GetForkScheduleResponse,
  GetGenesisResponse,
  GetHeaderResponseDeneb,
  GetHeaderResponseElectra,
  GetKeystoresResponse,
  GetNextWithdrawalsResponse,
  GetPoolAttesterSlashingsResponse,
  GetPoolProposerSlashingsResponse,
  GetPoolVoluntaryExitsResponse,
  GetRemoteKeystoresResponse,
  GetSpecVCResponse,
  GetStateFinalityCheckpointsResponse,
  GetStateForkResponse,
  GetStateRandaoResponse,
  GetStateRootResponse,
  GetStateValidatorBalancesResponse,
  GetStateValidatorResponse,
  GetStateValidatorsResponse,
  GetValidatorGasLimitResponse,
  HistoricalSummary,
  ImportDistributedKeystoresBody,
  ImportRemoteKeystoresBody,
  KeymanagerGenericError,
  KeystoreInfo,
  ListFeeRecipientResponse,
  ListGasLimitResponse,
  GetGraffitiResponse,
  GraffitiResponse,
  PendingAttestation,
  PendingConsolidation,
  PendingDeposit,
  PendingPartialWithdrawal,
  PostKeystoresResponse,
  PrepareBeaconProposer,
  ProposerSlashing,
  RemoteKeystoreInfo,
  RemoteSignerInfo,
  RequestItemStatus,
  RestAttesterDuty,
  RestBeaconCommitteeSelection,
  RestBeaconStatesCommittees,
  RestBeaconStatesFinalityCheckpoints,
  RestBlockHeader,
  RestBlockHeaderInfo,
  RestChainHeadV2,
  RestCommitteeSubscription,
  RestContributionAndProof,
  RestDepositContract,
  RestEpochRandao,
  RestEpochSyncCommittee,
  RestExtraData,
  RestGenesis,
  RestIndexedErrorMessage,
  RestIndexedErrorMessageItem,
  RestMetadata,
  RestNetworkIdentity,
  RestNimbusTimestamp1,
  RestNimbusTimestamp2,
  RestNode,
  RestNodeExtraData,
  RestNodePeer,
  RestNodeVersion,
  RestPeerCount,
  RestProposerDuty,
  RestRoot,
  RestSignedBlockHeader,
  RestSignedContributionAndProof,
  RestSyncCommitteeContribution,
  RestSyncCommitteeDuty,
  RestSyncCommitteeMessage,
  RestSyncCommitteeSelection,
  RestSyncCommitteeSubscription,
  RestSyncInfo,
  RestValidator,
  RestValidatorBalance,
  SPDIR,
  SPDIR_Meta,
  SPDIR_SignedAttestation,
  SPDIR_SignedBlock,
  SPDIR_Validator,
  SetFeeRecipientRequest,
  SetGasLimitRequest,
  SetGraffitiRequest,
  SignedBLSToExecutionChange,
  SignedBeaconBlockHeader,
  SignedContributionAndProof,
  SignedValidatorRegistrationV1,
  SignedVoluntaryExit,
  SubmitBlindedBlockResponseDeneb,
  SubmitBlindedBlockResponseElectra,
  SyncAggregate,
  SyncAggregatorSelectionData,
  SyncCommittee,
  SyncCommitteeContribution,
  SyncCommitteeMessage,
  Validator,
  ValidatorRegistrationV1,
  VoluntaryExit,
  Web3SignerAggregationSlotData,
  Web3SignerDepositData,
  Web3SignerErrorResponse,
  Web3SignerForkInfo,
  Web3SignerMerkleProof,
  Web3SignerRandaoRevealData,
  Web3SignerSignatureResponse,
  Web3SignerStatusResponse,
  Web3SignerSyncCommitteeMessageData,
  Web3SignerValidatorRegistration,
  Withdrawal,
  WithdrawalRequest,
  altair.BeaconBlock,
  altair.BeaconBlockBody,
  altair.BeaconState,
  altair.LightClientBootstrap,
  altair.LightClientFinalityUpdate,
  altair.LightClientHeader,
  altair.LightClientOptimisticUpdate,
  altair.LightClientUpdate,
  altair.SignedBeaconBlock,
  bellatrix.BeaconBlock,
  bellatrix.BeaconBlockBody,
  bellatrix.BeaconState,
  bellatrix.ExecutionPayload,
  bellatrix.ExecutionPayloadHeader,
  bellatrix.SignedBeaconBlock,
  bellatrix_mev.BlindedBeaconBlockBody,
  bellatrix_mev.BlindedBeaconBlock,
  bellatrix_mev.SignedBlindedBeaconBlock,
  capella.BeaconBlock,
  capella.BeaconBlockBody,
  capella.BeaconState,
  capella.ExecutionPayload,
  capella.ExecutionPayloadHeader,
  capella.LightClientBootstrap,
  capella.LightClientFinalityUpdate,
  capella.LightClientHeader,
  capella.LightClientOptimisticUpdate,
  capella.LightClientUpdate,
  capella.SignedBeaconBlock,
  capella_mev.BlindedBeaconBlock,
  capella_mev.BlindedBeaconBlockBody,
  capella_mev.SignedBlindedBeaconBlock,
  deneb.BeaconBlock,
  deneb.BeaconBlockBody,
  deneb.BeaconState,
  deneb.BlockContents,
  deneb.ExecutionPayload,
  deneb.ExecutionPayloadHeader,
  deneb.LightClientBootstrap,
  deneb.LightClientFinalityUpdate,
  deneb.LightClientHeader,
  deneb.LightClientOptimisticUpdate,
  deneb.LightClientUpdate,
  deneb.SignedBeaconBlock,
  deneb_mev.BlindedBeaconBlock,
  deneb_mev.BlindedBeaconBlockBody,
  deneb_mev.BuilderBid,
  deneb_mev.ExecutionPayloadAndBlobsBundle,
  deneb_mev.SignedBlindedBeaconBlock,
  deneb_mev.SignedBuilderBid,
  electra.AggregateAndProof,
  electra.Attestation,
  electra.AttesterSlashing,
  electra.BeaconBlock,
  electra.BeaconState,
  electra.BeaconBlockBody,
  electra.BlockContents,
  electra.ExecutionPayload,
  electra.ExecutionPayloadHeader,
  electra.IndexedAttestation,
  electra.LightClientBootstrap,
  electra.LightClientFinalityUpdate,
  electra.LightClientHeader,
  electra.LightClientOptimisticUpdate,
  electra.LightClientUpdate,
  electra.SignedAggregateAndProof,
  electra.SignedBeaconBlock,
  electra.TrustedAttestation,
  electra_mev.BlindedBeaconBlock,
  electra_mev.BlindedBeaconBlockBody,
  electra_mev.BuilderBid,
  electra_mev.ExecutionPayloadAndBlobsBundle,
  electra_mev.SignedBlindedBeaconBlock,
  electra_mev.SignedBuilderBid,
  fulu.BeaconBlock,
  fulu.BeaconBlockBody,
  fulu.BeaconState,
  fulu.BlockContents,
  fulu.ExecutionPayload,
  fulu.ExecutionPayloadHeader,
  fulu.SignedBeaconBlock,
  fulu_mev.BlindedBeaconBlock,
  fulu_mev.BlindedBeaconBlockBody,
  fulu_mev.BuilderBid,
  fulu_mev.ExecutionPayloadAndBlobsBundle,
  fulu_mev.SignedBlindedBeaconBlock,
  fulu_mev.SignedBuilderBid,
  phase0.AggregateAndProof,
  phase0.Attestation,
  phase0.AttesterSlashing,
  phase0.BeaconBlock,
  phase0.BeaconBlockBody,
  phase0.BeaconState,
  phase0.IndexedAttestation,
  phase0.SignedAggregateAndProof,
  phase0.SignedBeaconBlock,
  phase0.TrustedAttestation
)

# TODO
# Tuples are widely used in the responses of the REST server
# If we switch to concrete types there, it would be possible
# to remove this overly generic definition.
template writeValue*(w: JsonWriter[RestJson], value: tuple) =
  writeRecordValue(w, value)

## The RestJson format implements JSON serialization in the way specified
## by the Beacon API:
##
## https://ethereum.github.io/beacon-APIs/
##
## In this format, we must always set `allowUnknownFields = true` in the
## decode calls in order to conform the following spec:
##
## All JSON responses return the requested data under a data key in the top
## level of their response.  Additional metadata may or may not be present
## in other keys at the top level of the response, dependent on the endpoint.
## The rules that require an increase in version number are as follows:
##
## - no field that is listed in an endpoint shall be removed without an increase
##   in the version number
##
## - no field that is listed in an endpoint shall be altered in terms of format
##   (e.g. from a string to an array) without an increase in the version number
##
## Note that it is possible for a field to be added to an endpoint's data or
## metadata without an increase in the version number.
##
## TODO nim-json-serializations should allow setting up this policy per format
##
## This also means that when new fields are introduced to the object definitions
## below, one must use the `Opt[T]` type.

const
  DecimalSet = {'0' .. '9'}
    # Base10 (decimal) set of chars
  ValidatorKeySize = RawPubKeySize * 2
    # Size of `ValidatorPubKey` hexadecimal value (without 0x)
  ValidatorSigSize = RawSigSize * 2
    # Size of `ValidatorSig` hexadecimal value (without 0x)
  RootHashSize = sizeof(Eth2Digest) * 2
    # Size of `xxx_root` hexadecimal value (without 0x)

  ApplicationJsonMediaType* = MediaType.init("application/json")
  TextPlainMediaType* = MediaType.init("text/plain")
  OctetStreamMediaType* = MediaType.init("application/octet-stream")
  UrlEncodedMediaType* = MediaType.init("application/x-www-form-urlencoded")
  UnableDecodeVersionError = "Unable to decode version"
  UnableDecodeError = "Unable to decode data"
  UnexpectedDecodeError = "Unexpected decoding error"

type
  EncodeTypes* =
    BlobSidecarInfoObject |
    DeleteKeystoresBody |
    EmptyBody |
    ImportDistributedKeystoresBody |
    ImportRemoteKeystoresBody |
    KeystoresAndSlashingProtection |
    PrepareBeaconProposer |
    ProposerSlashing |
    SetFeeRecipientRequest |
    SetGasLimitRequest |
    bellatrix_mev.SignedBlindedBeaconBlock |
    capella_mev.SignedBlindedBeaconBlock |
    deneb_mev.SignedBlindedBeaconBlock |
    electra_mev.SignedBlindedBeaconBlock |
    fulu_mev.SignedBlindedBeaconBlock |
    phase0.AttesterSlashing |
    SignedValidatorRegistrationV1 |
    SignedVoluntaryExit |
    Web3SignerRequest |
    RestNimbusTimestamp1 |
    SetGraffitiRequest

  EncodeOctetTypes* =
    altair.SignedBeaconBlock |
    bellatrix.SignedBeaconBlock |
    capella.SignedBeaconBlock |
    phase0.SignedBeaconBlock |
    DenebSignedBlockContents |
    ElectraSignedBlockContents |
    FuluSignedBlockContents |
    ForkedMaybeBlindedBeaconBlock

  EncodeArrays* =
    seq[phase0.Attestation] |
    seq[electra.Attestation] |
    seq[PrepareBeaconProposer] |
    seq[RemoteKeystoreInfo] |
    seq[RestCommitteeSubscription] |
    seq[RestSignedContributionAndProof] |
    seq[RestSyncCommitteeMessage] |
    seq[RestSyncCommitteeSubscription] |
    seq[phase0.SignedAggregateAndProof] |
    seq[electra.SignedAggregateAndProof] |
    seq[SignedValidatorRegistrationV1] |
    seq[ValidatorIndex] |
    seq[RestBeaconCommitteeSelection] |
    seq[RestSyncCommitteeSelection]

  DecodeTypes* =
    DataEnclosedObject |
    DataMetaEnclosedObject |
    DataRootEnclosedObject |
    DataOptimisticObject |
    DataVersionEnclosedObject |
    DataOptimisticAndFinalizedObject |
    GetBlockV2Response |
    GetDistributedKeystoresResponse |
    GetKeystoresResponse |
    GetRemoteKeystoresResponse |
    GetStateForkResponse |
    GetStateV2Response |
    KeymanagerGenericError |
    KeystoresAndSlashingProtection |
    ListFeeRecipientResponse |
    PrepareBeaconProposer |
    RestIndexedErrorMessage |
    RestErrorMessage |
    RestValidator |
    Web3SignerErrorResponse |
    Web3SignerKeysResponse |
    Web3SignerSignatureResponse |
    Web3SignerStatusResponse |
    GetStateRootResponse |
    GetBlockRootResponse |
    SomeForkedLightClientObject |
    seq[SomeForkedLightClientObject] |
    RestNimbusTimestamp1 |
    RestNimbusTimestamp2 |
    GetGraffitiResponse |
    GetAggregatedAttestationV2Response

  RestVersioned*[T] = object
    data*: T
    jsonVersion*: ConsensusFork
    sszContext*: ForkDigest

  RestBlockTypes* = phase0.BeaconBlock | altair.BeaconBlock |
                    bellatrix.BeaconBlock | capella.BeaconBlock |
                    deneb.BlockContents | deneb_mev.BlindedBeaconBlock |
                    electra.BlockContents | fulu.BlockContents |
                    electra_mev.BlindedBeaconBlock |
                    fulu_mev.BlindedBeaconBlock

func readStrictHexChar(c: char, radix: static[uint8]): Result[int8, cstring] =
  ## Converts an hex char to an int
  const
    lowerLastChar = chr(ord('a') + radix - 11'u8)
    capitalLastChar = chr(ord('A') + radix - 11'u8)
  case c
  of '0' .. '9': ok(int8 ord(c) - ord('0'))
  of 'a' .. lowerLastChar: ok(int8 ord(c) - ord('a') + 10)
  of 'A' .. capitalLastChar: ok(int8 ord(c) - ord('A') + 10)
  else: err("Invalid hexadecimal character encountered!")

func readStrictDecChar(c: char, radix: static[uint8]): Result[int8, cstring] =
  const lastChar = char(ord('0') + radix - 1'u8)
  case c
  of '0' .. lastChar: ok(int8 ord(c) - ord('0'))
  else: err("Invalid decimal character encountered!")

func skipPrefixes(str: string,
                  radix: range[2..16]): Result[int, cstring] =
  ## Returns the index of the first meaningful char in `hexStr` by skipping
  ## "0x" prefix
  if len(str) < 2:
    return ok(0)

  return
    if str[0] == '0':
      if str[1] in {'x', 'X'}:
        if radix != 16:
          return err("Parsing mismatch, 0x prefix is only valid for a " &
                     "hexadecimal number (base 16)")
        ok(2)
      elif str[1] in {'o', 'O'}:
        if radix != 8:
          return err("Parsing mismatch, 0o prefix is only valid for an " &
                     "octal number (base 8)")
        ok(2)
      elif str[1] in {'b', 'B'}:
        if radix == 2:
          ok(2)
        elif radix == 16:
          # allow something like "0bcdef12345" which is a valid hex
          ok(0)
        else:
          err("Parsing mismatch, 0b prefix is only valid for a binary number " &
              "(base 2), or hex number")
      else:
        ok(0)
    else:
      ok(0)

func strictParse*[bits: static[int]](input: string,
                                     T: typedesc[StUint[bits]],
                                     radix: static[uint8] = 10
                                    ): Result[T, cstring] {.raises: [].} =
  var res: T
  static: doAssert (radix >= 2) and (radix <= 16),
            "Only base from 2..16 are supported"

  const
    base = radix.uint8.stuint(bits)
    zero = 0.uint8.stuint(256)

  var currentIndex =
    block:
      let res = skipPrefixes(input, radix)
      if res.isErr():
        return err(res.error)
      res.get()

  while currentIndex < len(input):
    let value =
      when radix <= 10:
        ? readStrictDecChar(input[currentIndex], radix)
      else:
        ? readStrictHexChar(input[currentIndex], radix)
    let mres = res * base
    if (res != zero) and (mres div base != res):
      return err("Overflow error")
    let ares = mres + value.stuint(bits)
    if ares < mres:
      return err("Overflow error")
    res = ares
    inc(currentIndex)
  ok(res)

proc prepareJsonResponse*(t: typedesc[RestApiResponse], d: auto): seq[byte] =
  let res =
    try:
      var stream = memoryOutput()
      var writer = JsonWriter[RestJson].init(stream)
      writer.beginRecord()
      writer.writeField("data", d)
      writer.endRecord()
      stream.getOutput(seq[byte])
    except IOError:
      default(seq[byte])
  res

proc prepareJsonStringResponse*[T: SomeForkedLightClientObject](
    t: typedesc[RestApiResponse], d: RestVersioned[T]): string =
  let res =
    try:
      var stream = memoryOutput()
      var writer = JsonWriter[RestJson].init(stream)
      withForkyObject(d.data):
        when lcDataFork > LightClientDataFork.None:
          writer.beginRecord()
          writer.writeField("version", d.jsonVersion.toString())
          writer.writeField("data", forkyObject)
          writer.endRecord()
      stream.getOutput(string)
    except IOError:
      default(string)
  res

proc prepareJsonStringResponse*(t: typedesc[RestApiResponse], d: auto): string =
  let res =
    try:
      var stream = memoryOutput()
      var writer = JsonWriter[RestJson].init(stream)
      writer.writeValue(d)
      stream.getOutput(string)
    except IOError:
      default(string)
  res

proc jsonResponseWRoot*(t: typedesc[RestApiResponse], data: auto,
                        dependent_root: Eth2Digest,
                        execOpt: Opt[bool]): RestApiResponse =
  let res =
    try:
      var stream = memoryOutput()
      var writer = JsonWriter[RestJson].init(stream)
      writer.beginRecord()
      writer.writeField("dependent_root", dependent_root)
      if execOpt.isSome():
        writer.writeField("execution_optimistic", execOpt.get())
      writer.writeField("data", data)
      writer.endRecord()
      stream.getOutput(seq[byte])
    except IOError:
      default(seq[byte])
  RestApiResponse.response(res, Http200, "application/json")

proc jsonResponse*(t: typedesc[RestApiResponse], data: auto): RestApiResponse =
  let res =
    try:
      var stream = memoryOutput()
      var writer = JsonWriter[RestJson].init(stream)
      writer.beginRecord()
      writer.writeField("data", data)
      writer.endRecord()
      stream.getOutput(seq[byte])
    except IOError:
      default(seq[byte])
  RestApiResponse.response(res, Http200, "application/json")

proc jsonResponseBlock*(t: typedesc[RestApiResponse],
                        data: ForkySignedBlindedBeaconBlock,
                        consensusFork: ConsensusFork,
                        execOpt: Opt[bool],
                        finalized: bool): RestApiResponse =
  let
    headers = [("eth-consensus-version", consensusFork.toString())]
    res =
      try:
        var stream = memoryOutput()
        var writer = JsonWriter[RestJson].init(stream)
        writer.beginRecord()
        writer.writeField("version", consensusFork.toString())
        if execOpt.isSome():
          writer.writeField("execution_optimistic", execOpt.get())
        writer.writeField("finalized", finalized)
        writer.writeField("data", data)
        writer.endRecord()
        stream.getOutput(seq[byte])
      except IOError:
        default(seq[byte])
  RestApiResponse.response(res, Http200, "application/json", headers = headers)

proc jsonResponseBlock*(t: typedesc[RestApiResponse],
                        data: ForkedSignedBeaconBlock,
                        execOpt: Opt[bool],
                        finalized: bool): RestApiResponse =
  let
    headers = [("eth-consensus-version", data.kind.toString())]
    res =
      try:
        var stream = memoryOutput()
        var writer = JsonWriter[RestJson].init(stream)
        writer.beginRecord()
        writer.writeField("version", data.kind.toString())
        if execOpt.isSome():
          writer.writeField("execution_optimistic", execOpt.get())
        writer.writeField("finalized", finalized)
        withBlck(data):
          writer.writeField("data", forkyBlck)
        writer.endRecord()
        stream.getOutput(seq[byte])
      except IOError:
        default(seq[byte])
  RestApiResponse.response(res, Http200, "application/json", headers = headers)

proc jsonResponseState*(t: typedesc[RestApiResponse],
                        data: ForkedHashedBeaconState,
                        execOpt: Opt[bool]): RestApiResponse =
  let
    headers = [("eth-consensus-version", data.kind.toString())]
    res =
      try:
        var stream = memoryOutput()
        var writer = JsonWriter[RestJson].init(stream)
        writer.beginRecord()
        writer.writeField("version", data.kind.toString())
        if execOpt.isSome():
          writer.writeField("execution_optimistic", execOpt.get())
        withState(data):
          writer.writeField("data", forkyState.data)
        writer.endRecord()
        stream.getOutput(seq[byte])
      except IOError:
        default(seq[byte])
  RestApiResponse.response(res, Http200, "application/json", headers = headers)

proc jsonResponseWOpt*(t: typedesc[RestApiResponse], data: auto,
                       execOpt: Opt[bool]): RestApiResponse =
  let res =
    try:
      var stream = memoryOutput()
      var writer = JsonWriter[RestJson].init(stream)
      writer.beginRecord()
      if execOpt.isSome():
        writer.writeField("execution_optimistic", execOpt.get())
      writer.writeField("data", data)
      writer.endRecord()
      stream.getOutput(seq[byte])
    except IOError:
      default(seq[byte])
  RestApiResponse.response(res, Http200, "application/json")

proc prepareJsonResponseFinalized*(
    t: typedesc[RestApiResponse], data: auto, exec: Opt[bool],
    finalized: bool
): seq[byte] =
  try:
    var
      stream = memoryOutput()
      writer = JsonWriter[RestJson].init(stream)
    writer.beginRecord()
    if exec.isSome():
      writer.writeField("execution_optimistic", exec.get())
    writer.writeField("finalized", finalized)
    writer.writeField("data", data)
    writer.endRecord()
    stream.getOutput(seq[byte])
  except IOError:
    default(seq[byte])

proc jsonResponseFinalized*(t: typedesc[RestApiResponse], data: auto,
                            exec: Opt[bool],
                            finalized: bool): RestApiResponse =
  let res = RestApiResponse.prepareJsonResponseFinalized(data, exec, finalized)
  RestApiResponse.response(res, Http200, "application/json")

proc jsonResponseFinalizedWVersion*(t: typedesc[RestApiResponse],
                            data: auto,
                            exec: Opt[bool],
                            finalized: bool,
                            version: ConsensusFork): RestApiResponse =
  let
    headers = [("eth-consensus-version", version.toString())]
    res =
      block:
        var default: seq[byte]
        try:
          var stream = memoryOutput()
          var writer = JsonWriter[RestJson].init(stream)
          writer.beginRecord()
          writer.writeField("version", version.toString())
          if exec.isSome():
            writer.writeField("execution_optimistic", exec.get())
          writer.writeField("finalized", finalized)
          writer.writeField("data", data)
          writer.endRecord()
          stream.getOutput(seq[byte])
        except IOError:
          default
  RestApiResponse.response(res, Http200, "application/json", headers = headers)

proc jsonResponseWVersion*(t: typedesc[RestApiResponse], data: auto,
                           version: ConsensusFork): RestApiResponse =
  let
    headers = [("eth-consensus-version", version.toString())]
    res =
      try:
        var stream = memoryOutput()
        var writer = JsonWriter[RestJson].init(stream)
        writer.beginRecord()
        writer.writeField("version", version.toString())
        writer.writeField("data", data)
        writer.endRecord()
        stream.getOutput(seq[byte])
      except IOError:
        default(seq[byte])
  RestApiResponse.response(res, Http200, "application/json", headers = headers)

proc jsonResponseVersioned*[T: SomeForkedLightClientObject](
    t: typedesc[RestApiResponse],
    entries: openArray[RestVersioned[T]]): RestApiResponse =
  let res =
    try:
      var stream = memoryOutput()
      var writer = JsonWriter[RestJson].init(stream)
      for e in writer.stepwiseArrayCreation(entries):
        withForkyObject(e.data):
          when lcDataFork > LightClientDataFork.None:
            writer.beginRecord()
            writer.writeField("version", e.jsonVersion.toString())
            writer.writeField("data", forkyObject)
            writer.endRecord()
      stream.getOutput(seq[byte])
    except IOError:
      default(seq[byte])
  RestApiResponse.response(res, Http200, "application/json")

proc jsonResponsePlain*(t: typedesc[RestApiResponse],
                        data: auto): RestApiResponse =
  let res =
    try:
      var stream = memoryOutput()
      var writer = JsonWriter[RestJson].init(stream)
      writer.writeValue(data)
      stream.getOutput(seq[byte])
    except IOError:
      default(seq[byte])
  RestApiResponse.response(res, Http200, "application/json")

proc jsonResponsePlain*(t: typedesc[RestApiResponse],
                        data: auto, headers: HttpTable): RestApiResponse =
  let res =
    try:
      var stream = memoryOutput()
      var writer = JsonWriter[RestJson].init(stream)
      writer.writeValue(data)
      stream.getOutput(seq[byte])
    except IOError:
      default(seq[byte])
  RestApiResponse.response(res, Http200, "application/json", headers = headers)

proc jsonResponseWMeta*(t: typedesc[RestApiResponse],
                        data: auto, meta: auto): RestApiResponse =
  let res =
    try:
      var stream = memoryOutput()
      var writer = JsonWriter[RestJson].init(stream)
      writer.beginRecord()
      writer.writeField("data", data)
      writer.writeField("meta", meta)
      writer.endRecord()
      stream.getOutput(seq[byte])
    except IOError:
      default(seq[byte])
  RestApiResponse.response(res, Http200, "application/json")

proc jsonMsgResponse*(t: typedesc[RestApiResponse],
                      msg: string = ""): RestApiResponse =
  let data =
    try:
      var stream = memoryOutput()
      var writer = JsonWriter[RestJson].init(stream)
      writer.beginRecord()
      writer.writeField("code", 200)
      writer.writeField("message", msg)
      writer.endRecord()
      stream.getOutput(seq[byte])
    except IOError:
      default(seq[byte])
  RestApiResponse.response(data, Http200, "application/json")

proc jsonError*(t: typedesc[RestApiResponse], status: HttpCode = Http200,
                msg: string = ""): RestApiResponse =
  let data =
    try:
      var stream = memoryOutput()
      var writer = JsonWriter[RestJson].init(stream)
      writer.beginRecord()
      writer.writeField("code", int(status.toInt()))
      writer.writeField("message", msg)
      writer.endRecord()
      stream.getOutput(string)
    except IOError:
      default(string)
  RestApiResponse.error(status, data, "application/json")

proc jsonError*(t: typedesc[RestApiResponse], status: HttpCode = Http200,
                msg: string = "", stacktrace: string): RestApiResponse =
  let data =
    try:
      var stream = memoryOutput()
      var writer = JsonWriter[RestJson].init(stream)
      writer.beginRecord()
      writer.writeField("code", int(status.toInt()))
      writer.writeField("message", msg)
      if len(stacktrace) > 0:
        writer.writeField("stacktraces", [stacktrace])
      writer.endRecord()
      stream.getOutput(string)
    except IOError:
      default(string)
  RestApiResponse.error(status, data, "application/json")

proc jsonError*(t: typedesc[RestApiResponse], status: HttpCode = Http200,
                msg: string = "",
                stacktraces: openArray[string]): RestApiResponse =
  let data =
    try:
      var stream = memoryOutput()
      var writer = JsonWriter[RestJson].init(stream)
      writer.beginRecord()
      writer.writeField("code", int(status.toInt()))
      writer.writeField("message", msg)
      writer.writeField("stacktraces", stacktraces)
      writer.endRecord()
      stream.getOutput(string)
    except IOError:
      default(string)
  RestApiResponse.error(status, data, "application/json")

proc jsonError*(t: typedesc[RestApiResponse],
                rmsg: RestErrorMessage): RestApiResponse =
  let data =
    try:
      var stream = memoryOutput()
      var writer = JsonWriter[RestJson].init(stream)
      writer.beginRecord()
      writer.writeField("code", rmsg.code)
      writer.writeField("message", rmsg.message)
      if rmsg.stacktraces.isSome():
        writer.writeField("stacktraces", rmsg.stacktraces)
      writer.endRecord()
      stream.getOutput(string)
    except IOError:
      default(string)
  RestApiResponse.error(rmsg.code.toHttpCode().get(), data, "application/json")

proc jsonErrorList*(t: typedesc[RestApiResponse],
                    status: HttpCode = Http200,
                    msg: string = "", failures: auto): RestApiResponse =
  let data =
    try:
      var stream = memoryOutput()
      var writer = JsonWriter[RestJson].init(stream)
      writer.beginRecord()
      writer.writeField("code", int(status.toInt()))
      writer.writeField("message", msg)
      writer.writeField("failures", failures)
      writer.endRecord()
      stream.getOutput(string)
    except IOError:
      default(string)
  RestApiResponse.error(status, data, "application/json")

proc sszResponseVersioned*[T: SomeForkedLightClientObject](
    t: typedesc[RestApiResponse],
    entries: openArray[RestVersioned[T]]): RestApiResponse =
  let res =
    try:
      var stream = memoryOutput()
      for e in entries:
        withForkyUpdate(e.data):
          when lcDataFork > LightClientDataFork.None:
            var cursor = stream.delayFixedSizeWrite(sizeof(uint64))
            let initPos = stream.pos
            stream.write e.sszContext.data
            var writer = SszWriter.init(stream)
            writer.writeValue forkyUpdate
            cursor.finalWrite (stream.pos - initPos).uint64.toBytesLE()
      stream.getOutput(seq[byte])
    except IOError:
      default(seq[byte])
  RestApiResponse.response(res, Http200, "application/octet-stream")

proc sszResponsePlain*(t: typedesc[RestApiResponse], res: seq[byte],
                       headers: openArray[RestKeyValueTuple] = []
                      ): RestApiResponse =
  RestApiResponse.response(res, Http200, "application/octet-stream",
                           headers = headers)

proc sszResponse*(t: typedesc[RestApiResponse], data: auto,
                  headers: openArray[RestKeyValueTuple] = []
                 ): RestApiResponse =
  let res =
    try:
      var stream = memoryOutput()
      var writer = SszWriter.init(stream)
      writer.writeValue(data)
      stream.getOutput(seq[byte])
    except IOError:
      default(seq[byte])
  RestApiResponse.response(res, Http200, "application/octet-stream",
                           headers = headers)

proc sszResponse*(t: typedesc[RestApiResponse], data: auto,
                  headers: HttpTable): RestApiResponse =
  let res =
    try:
      var stream = memoryOutput()
      var writer = SszWriter.init(stream)
      writer.writeValue(data)
      stream.getOutput(seq[byte])
    except IOError:
      default(seq[byte])
  RestApiResponse.response(res, Http200, "application/octet-stream",
                           headers = headers)

template hexOriginal(data: openArray[byte]): string =
  to0xHex(data)

proc decodeJsonString*[T](t: typedesc[T],
                          data: JsonString): Result[T, cstring] =
  try:
    ok(RestJson.decode(string(data), T,
                       requireAllFields = true,
                       allowUnknownFields = true))
  except SerializationError:
    err("Unable to deserialize data")

## uint64
proc writeValue*(
    w: var JsonWriter[RestJson], value: uint64) {.raises: [IOError].} =
  writeValue(w, Base10.toString(value))

proc readValue*(reader: var JsonReader[RestJson], value: var uint64) {.
     raises: [IOError, SerializationError].} =
  let svalue = reader.readValue(string)
  let res = Base10.decode(uint64, svalue)
  if res.isOk():
    value = res.get()
  else:
    reader.raiseUnexpectedValue($res.error() & ": " & svalue)

## RestReward
proc writeValue*(
    w: var JsonWriter[RestJson], value: RestReward) {.raises: [IOError].} =
  writeValue(w, $int64(value))

proc readValue*(reader: var JsonReader[RestJson], value: var RestReward) {.
     raises: [IOError, SerializationError].} =
  let svalue = reader.readValue(string)
  if svalue.startsWith("-"):
    let res =
      Base10.decode(uint64, svalue.toOpenArray(1, len(svalue) - 1)).valueOr:
        reader.raiseUnexpectedValue($error & ": " & svalue)
    if res > uint64(high(int64)):
      reader.raiseUnexpectedValue("Integer value overflow " & svalue)
    value = RestReward(-int64(res))
  else:
    let res =
      Base10.decode(uint64, svalue).valueOr:
        reader.raiseUnexpectedValue($error & ": " & svalue)
    if res > uint64(high(int64)):
      reader.raiseUnexpectedValue("Integer value overflow " & svalue)
    value = RestReward(int64(res))

## uint8
proc writeValue*(
    w: var JsonWriter[RestJson], value: uint8) {.raises: [IOError].} =
  writeValue(w, Base10.toString(value))

proc readValue*(reader: var JsonReader[RestJson], value: var uint8) {.
     raises: [IOError, SerializationError].} =
  let svalue = reader.readValue(string)
  let res = Base10.decode(uint8, svalue)
  if res.isOk():
    value = res.get()
  else:
    reader.raiseUnexpectedValue($res.error() & ": " & svalue)

## BlockNumber/Quantity
proc writeValue*(
    w: var JsonWriter[RestJson], value: Quantity) {.raises: [IOError].} =
  w.writeValue(distinctBase(value))

proc readValue*(
    reader: var JsonReader[RestJson],
    value: var Quantity) {.raises: [IOError, SerializationError].} =
  reader.readValue(distinctBase(value))

## RestNumeric
proc writeValue*(w: var JsonWriter[RestJson],
                 value: RestNumeric) {.raises: [IOError].} =
  writeValue(w, int(value))

proc readValue*(reader: var JsonReader[RestJson],
                value: var RestNumeric) {.
     raises: [IOError, SerializationError].} =
  value = RestNumeric(reader.readValue(int))

## JustificationBits
proc writeValue*(
    w: var JsonWriter[RestJson], value: JustificationBits
) {.raises: [IOError].} =
  w.writeValue hexOriginal([uint8(value)])

proc readValue*(reader: var JsonReader[RestJson], value: var JustificationBits) {.
    raises: [IOError, SerializationError].} =
  let hex = reader.readValue(string)
  try:
    value = JustificationBits(hexToByteArray(hex, 1)[0])
  except ValueError:
    raiseUnexpectedValue(reader,
                        "The `justification_bits` value must be a hex string")

## UInt256
proc writeValue*(
    w: var JsonWriter[RestJson], value: UInt256) {.raises: [IOError].} =
  writeValue(w, toString(value))

proc readValue*(reader: var JsonReader[RestJson], value: var UInt256) {.
     raises: [IOError, SerializationError].} =
  let svalue = reader.readValue(string)
  try:
    value = parse(svalue, UInt256, 10)
  except ValueError:
    raiseUnexpectedValue(reader,
                         "UInt256 value should be a valid decimal string")

## Gwei
proc writeValue*(
    writer: var JsonWriter[RestJson], value: Gwei) {.raises: [IOError].} =
  writer.writeValue(distinctBase(value))

proc readValue*(
    reader: var JsonReader[RestJson],
    value: var Gwei) {.raises: [IOError, SerializationError].} =
  reader.readValue(distinctBase(value))

## Slot
proc writeValue*(
    writer: var JsonWriter[RestJson], value: Slot) {.raises: [IOError].} =
  writeValue(writer, Base10.toString(uint64(value)))

proc readValue*(reader: var JsonReader[RestJson], value: var Slot) {.
     raises: [IOError, SerializationError].} =
  let svalue = reader.readValue(string)
  let res = Base10.decode(uint64, svalue)
  if res.isOk():
    value = Slot(res.get())
  else:
    reader.raiseUnexpectedValue($res.error())

## Epoch
proc writeValue*(
    writer: var JsonWriter[RestJson], value: Epoch) {.raises: [IOError].} =
  writeValue(writer, Base10.toString(uint64(value)))

proc readValue*(reader: var JsonReader[RestJson], value: var Epoch) {.
     raises: [IOError, SerializationError].} =
  let svalue = reader.readValue(string)
  let res = Base10.decode(uint64, svalue)
  if res.isOk():
    value = Epoch(res.get())
  else:
    reader.raiseUnexpectedValue($res.error())

## EpochParticipationFlags
proc writeValue*(
    writer: var JsonWriter[RestJson], epochFlags: EpochParticipationFlags
) {.raises: [IOError].} =
  for e in writer.stepwiseArrayCreation(epochFlags.asList):
    writer.writeValue $e

proc readValue*(reader: var JsonReader[RestJson],
                epochFlags: var EpochParticipationFlags)
               {.raises: [SerializationError, IOError].} =
  for e in reader.readArray(string):
    let parsed = try:
      parseBiggestUInt(e)
    except ValueError:
      reader.raiseUnexpectedValue(
        "A string-encoded 8-bit usigned integer value expected")

    if parsed > uint8.high:
      reader.raiseUnexpectedValue(
        "The unsigned integer value should fit in 8 bits")

    if not epochFlags.asList.add(uint8(parsed)):
      reader.raiseUnexpectedValue(
        "The participation flags list size exceeds limit")

## ValidatorIndex
proc writeValue*(
    writer: var JsonWriter[RestJson], value: ValidatorIndex
) {.raises: [IOError].} =
  writeValue(writer, Base10.toString(uint64(value)))

proc readValue*(reader: var JsonReader[RestJson], value: var ValidatorIndex)
               {.raises: [IOError, SerializationError].} =
  let svalue = reader.readValue(string)
  let res = Base10.decode(uint64, svalue)
  if res.isOk():
    let v = res.get()
    if v < VALIDATOR_REGISTRY_LIMIT:
      value = ValidatorIndex(v)
    else:
      reader.raiseUnexpectedValue(
        "Validator index is bigger then VALIDATOR_REGISTRY_LIMIT")
  else:
    reader.raiseUnexpectedValue($res.error())

## IndexInSyncCommittee
proc writeValue*(
    writer: var JsonWriter[RestJson], value: IndexInSyncCommittee
) {.raises: [IOError].} =
  writeValue(writer, Base10.toString(distinctBase(value)))

proc readValue*(reader: var JsonReader[RestJson], value: var IndexInSyncCommittee)
               {.raises: [IOError, SerializationError].} =
  let svalue = reader.readValue(string)
  let res = Base10.decode(uint64, svalue)
  if res.isOk():
    let v = res.get()
    if v < SYNC_COMMITTEE_SIZE:
      value = IndexInSyncCommittee(v)
    else:
      reader.raiseUnexpectedValue(
        "Index in committee is bigger than SYNC_COMMITTEE_SIZE")
  else:
    reader.raiseUnexpectedValue($res.error())

## RestValidatorIndex
proc writeValue*(
    writer: var JsonWriter[RestJson], value: RestValidatorIndex
) {.raises: [IOError].} =
  writeValue(writer, Base10.toString(uint64(value)))

proc readValue*(reader: var JsonReader[RestJson],
                value: var RestValidatorIndex) {.
     raises: [IOError, SerializationError].} =
  let svalue = reader.readValue(string)
  let res = Base10.decode(uint64, svalue)
  if res.isOk():
    let v = res.get()
    value = RestValidatorIndex(v)
  else:
    reader.raiseUnexpectedValue($res.error())

## CommitteeIndex
proc writeValue*(
    writer: var JsonWriter[RestJson], value: CommitteeIndex
) {.raises: [IOError].} =
  writeValue(writer, value.asUInt64)

proc readValue*(reader: var JsonReader[RestJson], value: var CommitteeIndex) {.
     raises: [IOError, SerializationError].} =
  var v: uint64
  reader.readValue(v)

  let res = CommitteeIndex.init(v)
  if res.isOk():
    value = res.get()
  else:
    reader.raiseUnexpectedValue($res.error())

## ValidatorSig
proc writeValue*(
    writer: var JsonWriter[RestJson], value: ValidatorSig
) {.raises: [IOError].} =
  writeValue(writer, hexOriginal(toRaw(value)))

proc readValue*(reader: var JsonReader[RestJson], value: var ValidatorSig) {.
     raises: [IOError, SerializationError].} =
  let hexValue = reader.readValue(string)
  let res = ValidatorSig.fromHex(hexValue)
  if res.isOk():
    value = res.get()
  else:
    reader.raiseUnexpectedValue($res.error())

## TrustedSig
proc writeValue*(
    writer: var JsonWriter[RestJson], value: TrustedSig
) {.raises: [IOError].} =
  writeValue(writer, hexOriginal(toRaw(value)))

proc readValue*(reader: var JsonReader[RestJson], value: var TrustedSig) {.
     raises: [IOError, SerializationError].} =
  let hexValue = reader.readValue(string)
  let res = ValidatorSig.fromHex(hexValue)
  if res.isOk():
    value = cast[TrustedSig](res.get())
  else:
    reader.raiseUnexpectedValue($res.error())

## ValidatorPubKey
proc writeValue*(
    writer: var JsonWriter[RestJson], value: ValidatorPubKey
) {.raises: [IOError].} =
  writeValue(writer, hexOriginal(toRaw(value)))

proc readValue*(reader: var JsonReader[RestJson], value: var ValidatorPubKey) {.
     raises: [IOError, SerializationError].} =
  let hexValue = reader.readValue(string)
  let res = ValidatorPubKey.fromHex(hexValue)
  if res.isOk():
    value = res.get()
  else:
    reader.raiseUnexpectedValue($res.error())

proc readValue*(reader: var JsonReader[RestJson], value: var HashedValidatorPubKey) {.
     raises: [IOError, SerializationError].} =
  var key: ValidatorPubKey
  readValue(reader, key)

  value = HashedValidatorPubKey.init(key)

proc writeValue*(
    writer: var JsonWriter[RestJson], value: HashedValidatorPubKey) {.raises: [IOError].} =
  writeValue(writer, value.pubkey)

## BitSeq
proc readValue*(reader: var JsonReader[RestJson], value: var BitSeq) {.
     raises: [IOError, SerializationError].} =
  try:
    value = BitSeq hexToSeqByte(reader.readValue(string))
  except ValueError:
    raiseUnexpectedValue(reader, "A BitSeq value should be a valid hex string")

proc writeValue*(
    writer: var JsonWriter[RestJson], value: BitSeq) {.raises: [IOError].} =
  writeValue(writer, hexOriginal(value.bytes()))

## BitList
proc readValue*(reader: var JsonReader[RestJson], value: var BitList) {.
     raises: [IOError, SerializationError].} =
  type T = type(value)
  value = T readValue(reader, BitSeq)

proc writeValue*(
    writer: var JsonWriter[RestJson], value: BitList) {.raises: [IOError].} =
  writeValue(writer, BitSeq value)

## BitArray
proc readValue*(reader: var JsonReader[RestJson], value: var BitArray) {.
     raises: [IOError, SerializationError].} =
  try:
    hexToByteArray(readValue(reader, string), value.bytes)
  except ValueError:
    raiseUnexpectedValue(reader,
                         "A BitArray value should be a valid hex string")

proc writeValue*(
    writer: var JsonWriter[RestJson], value: BitArray) {.raises: [IOError].} =
  writeValue(writer, hexOriginal(value.bytes))

## BlockHash/Hash32
proc readValue*(reader: var JsonReader[RestJson], value: var Hash32) {.
     raises: [IOError, SerializationError].} =
  try:
    hexToByteArray(reader.readValue(string), distinctBase(value))
  except ValueError:
    raiseUnexpectedValue(reader,
                         "Hash32 value should be a valid hex string")

proc writeValue*(
    writer: var JsonWriter[RestJson], value: Hash32) {.raises: [IOError].} =
  writeValue(writer, hexOriginal(distinctBase(value)))

## Eth2Digest
proc readValue*(reader: var JsonReader[RestJson], value: var Eth2Digest) {.
     raises: [IOError, SerializationError].} =
  try:
    hexToByteArray(reader.readValue(string), value.data)
  except ValueError:
    raiseUnexpectedValue(reader,
                         "Eth2Digest value should be a valid hex string")

proc writeValue*(
    writer: var JsonWriter[RestJson], value: Eth2Digest) {.raises: [IOError].} =
  writeValue(writer, hexOriginal(value.data))

## BloomLogs
proc readValue*(reader: var JsonReader[RestJson], value: var BloomLogs) {.
     raises: [IOError, SerializationError].} =
  try:
    hexToByteArray(reader.readValue(string), value.data)
  except ValueError:
    raiseUnexpectedValue(reader,
                         "BloomLogs value should be a valid hex string")

proc writeValue*(
    writer: var JsonWriter[RestJson], value: BloomLogs) {.raises: [IOError].} =
  writeValue(writer, hexOriginal(value.data))

## HashArray
proc readValue*(reader: var JsonReader[RestJson], value: var HashArray) {.
     raises: [IOError, SerializationError].} =
  readValue(reader, value.data)

proc writeValue*(
    writer: var JsonWriter[RestJson], value: HashArray) {.raises: [IOError].} =
  writeValue(writer, value.data)

## HashList
proc readValue*(reader: var JsonReader[RestJson], value: var HashList) {.
     raises: [IOError, SerializationError].} =
  readValue(reader, value.data)
  value.resetCache()

proc writeValue*(
    writer: var JsonWriter[RestJson], value: HashList) {.raises: [IOError].} =
  writeValue(writer, value.data)

## Eth1Address
proc readValue*(reader: var JsonReader[RestJson], value: var Eth1Address) {.
     raises: [IOError, SerializationError].} =
  try:
    hexToByteArray(reader.readValue(string), distinctBase(value))
  except ValueError:
    raiseUnexpectedValue(reader,
                         "Eth1Address value should be a valid hex string")

proc writeValue*(
    writer: var JsonWriter[RestJson], value: Eth1Address
) {.raises: [IOError].} =
  writeValue(writer, hexOriginal(distinctBase(value)))

## Blob
## https://github.com/ethereum/beacon-APIs/blob/v2.4.2/types/primitive.yaml#L129-L133
proc readValue*(reader: var JsonReader[RestJson], value: var Blob) {.
     raises: [IOError, SerializationError].} =
  try:
    hexToByteArray(reader.readValue(string), distinctBase(value))
  except ValueError:
    raiseUnexpectedValue(reader,
                         "Blob value should be a valid hex string")

proc writeValue*(
    writer: var JsonWriter[RestJson], value: Blob
) {.raises: [IOError].} =
  writeValue(writer, hexOriginal(distinctBase(value)))

## KzgCommitment and KzgProof; both are the same type, but this makes it
## explicit.
## https://github.com/ethereum/beacon-APIs/blob/v2.4.2/types/primitive.yaml#L135-L146
proc readValue*(reader: var JsonReader[RestJson],
     value: var (KzgCommitment|KzgProof)) {.
     raises: [IOError, SerializationError].} =
  try:
    hexToByteArray(reader.readValue(string), distinctBase(value.bytes))
  except ValueError:
    raiseUnexpectedValue(reader,
                         "KzgCommitment value should be a valid hex string")

proc writeValue*(
    writer: var JsonWriter[RestJson], value: KzgCommitment | KzgProof
) {.raises: [IOError].} =
  writeValue(writer, hexOriginal(distinctBase(value.bytes)))

## GraffitiBytes
proc writeValue*(
    writer: var JsonWriter[RestJson], value: GraffitiBytes
) {.raises: [IOError].} =
  writeValue(writer, hexOriginal(distinctBase(value)))

proc readValue*(reader: var JsonReader[RestJson], T: type GraffitiBytes): T
               {.raises: [IOError, SerializationError].} =
  try:
    init(GraffitiBytes, reader.readValue(string))
  except ValueError as err:
    reader.raiseUnexpectedValue err.msg

## Version | ForkDigest | DomainType | GraffitiBytes | RestWithdrawalPrefix
proc readValue*(
    reader: var JsonReader[RestJson],
    value: var (Version | ForkDigest | DomainType | GraffitiBytes |
                RestWithdrawalPrefix)) {.
     raises: [IOError, SerializationError].} =
  try:
    hexToByteArray(reader.readValue(string), distinctBase(value))
  except ValueError:
    raiseUnexpectedValue(
      reader, "Expected a valid hex string with " & $value.len() & " bytes")

template unrecognizedFieldWarning(fieldNameParam, typeNameParam: string) =
  # TODO: There should be a different notification mechanism for informing the
  #       caller of a deserialization routine for unexpected fields.
  #       The chonicles import in this module should be removed.
  trace "JSON field not recognized by the current version of Nimbus. Consider upgrading",
        fieldName = fieldNameParam, typeName = typeNameParam

template unrecognizedFieldIgnore =
  discard readValue(reader, JsonString)

## ForkedBeaconBlock
template prepareForkedBlockReading(blockType: typedesc,
                                   reader: var JsonReader[RestJson],
                                   version: var Opt[ConsensusFork],
                                   data: var Opt[JsonString],
                                   blinded: var Opt[bool],
                                   payloadValue: var Opt[UInt256],
                                   blockValue: var Opt[UInt256]) =
  for fieldName {.inject.} in readObjectFields(reader):
    case fieldName
    of "version":
      if version.isSome():
        reader.raiseUnexpectedField("Multiple version fields found",
                                    blockType.name)
      let vres = reader.readValue(string).toLowerAscii()
      version = ConsensusFork.init(vres)
      if version.isNone():
        reader.raiseUnexpectedValue("Incorrect version field value")
    of "data":
      when (blockType is ForkedBlindedBeaconBlock) or
           (blockType is ProduceBlockResponseV3):
        if data.isSome():
          reader.raiseUnexpectedField(
            "Multiple '" & fieldName & "' fields found", blockType.name)
        data = Opt.some(reader.readValue(JsonString))
      else:
        unrecognizedFieldWarning(fieldName, blockType.name)
    of "block_header", "block":
      when (blockType is Web3SignerForkedBeaconBlock):
        if data.isSome():
          reader.raiseUnexpectedField(
            "Multiple '" & fieldName & "' fields found", blockType.name)
        data = Opt.some(reader.readValue(JsonString))
      else:
        unrecognizedFieldWarning(fieldName, blockType.name)
    of "execution_payload_blinded":
      when (blockType is ProduceBlockResponseV3):
        if blinded.isSome():
          reader.raiseUnexpectedField(
            "Multiple `execution_payload_blinded` fields found", blockType.name)
        blinded = Opt.some(reader.readValue(bool))
      else:
        unrecognizedFieldWarning(fieldName, blockType.name)
    of "execution_payload_value":
      when (blockType is ProduceBlockResponseV3):
        if payloadValue.isSome():
          reader.raiseUnexpectedField(
            "Multiple `execution_payload_value` fields found", blockType.name)
        payloadValue = Opt.some(reader.readValue(UInt256))
      else:
        unrecognizedFieldWarning(fieldName, blockType.name)
    of "consensus_block_value":
      when (blockType is ProduceBlockResponseV3):
        if blockValue.isSome():
          reader.raiseUnexpectedField(
            "Multiple `consensus_block_value` fields found", blockType.name)
        blockValue = Opt.some(reader.readValue(UInt256))
      else:
        unrecognizedFieldWarning(fieldName, blockType.name)
    else:
      unrecognizedFieldWarning(fieldName, blockType.name)

  if version.isNone():
    reader.raiseUnexpectedValue("Field `version` is missing")
  if data.isNone():
    reader.raiseUnexpectedValue("Field `data` is missing")

proc readValue*[BlockType: ForkedBlindedBeaconBlock](
       reader: var JsonReader[RestJson],
       value: var BlockType
     ) {.raises: [IOError, SerializationError].} =
  var
    version: Opt[ConsensusFork]
    data: Opt[JsonString]
    blinded: Opt[bool]
    payloadValue: Opt[UInt256]
    blockValue: Opt[UInt256]

  prepareForkedBlockReading(BlockType, reader, version, data, blinded,
                            payloadValue, blockValue)

  case version.get():
  of ConsensusFork.Phase0:
    let res =
      try:
        RestJson.decode(string(data.get()),
                        phase0.BeaconBlock,
                        requireAllFields = true,
                        allowUnknownFields = true)
      except SerializationError as exc:
        reader.raiseUnexpectedValue("Incorrect phase0 block format, [" &
                                    exc.formatMsg("BlindedBlock") & "]")

    value = ForkedBlindedBeaconBlock(kind: ConsensusFork.Phase0,
                                     phase0Data: res)
  of ConsensusFork.Altair:
    let res =
      try:
        RestJson.decode(string(data.get()),
                        altair.BeaconBlock,
                        requireAllFields = true,
                        allowUnknownFields = true)
      except SerializationError as exc:
        reader.raiseUnexpectedValue("Incorrect altair block format, [" &
                                    exc.formatMsg("BlindedBlock") & "]")
    value = ForkedBlindedBeaconBlock(kind: ConsensusFork.Altair,
                                     altairData: res)
  of ConsensusFork.Bellatrix .. ConsensusFork.Capella:
    reader.raiseUnexpectedValue("pre-Deneb blinded block formats unsupported")
  of ConsensusFork.Deneb:
    let res =
      try:
        RestJson.decode(string(data.get()),
                        deneb_mev.BlindedBeaconBlock,
                        requireAllFields = true,
                        allowUnknownFields = true)
      except SerializationError as exc:
        reader.raiseUnexpectedValue("Incorrect deneb block format, [" &
                                    exc.formatMsg("BlindedBlock") & "]")
    value = ForkedBlindedBeaconBlock(kind: ConsensusFork.Deneb,
                                     denebData: res)
  of ConsensusFork.Electra:
    let res =
      try:
        RestJson.decode(string(data.get()),
                        electra_mev.BlindedBeaconBlock,
                        requireAllFields = true,
                        allowUnknownFields = true)
      except SerializationError as exc:
        reader.raiseUnexpectedValue("Incorrect electra block format, [" &
                                    exc.formatMsg("BlindedBlock") & "]")
    value = ForkedBlindedBeaconBlock(kind: ConsensusFork.Electra,
                                     electraData: res)
  of ConsensusFork.Fulu:
    let res =
      try:
        RestJson.decode(string(data.get()),
                        fulu_mev.BlindedBeaconBlock,
                        requireAllFields = true,
                        allowUnknownFields = true)
      except SerializationError as exc:
        reader.raiseUnexpectedValue("Incorrect electra block format, [" &
                                    exc.formatMsg("BlindedBlock") & "]")
    value = ForkedBlindedBeaconBlock(kind: ConsensusFork.Fulu,
                                     fuluData: res)

proc readValue*[BlockType: Web3SignerForkedBeaconBlock](
    reader: var JsonReader[RestJson],
    value: var BlockType) {.raises: [IOError, SerializationError].} =
  var
    version: Opt[ConsensusFork]
    data: Opt[JsonString]
    blinded: Opt[bool]
    payloadValue: Opt[UInt256]
    blockValue: Opt[UInt256]

  prepareForkedBlockReading(BlockType, reader, version, data, blinded,
                            payloadValue, blockValue)

  if version.get() <= ConsensusFork.Altair:
    reader.raiseUnexpectedValue(
      "Web3Signer implementation supports Capella and newer")

  let res =
    try:
      RestJson.decode(string(data.get()),
                      BeaconBlockHeader,
                      requireAllFields = true,
                      allowUnknownFields = true)
    except SerializationError:
      reader.raiseUnexpectedValue("Incorrect block header format")

  value = Web3SignerForkedBeaconBlock(kind: version.get(), data: res)

proc writeValue*[BlockType: Web3SignerForkedBeaconBlock](
    writer: var JsonWriter[RestJson], value: BlockType) {.raises: [IOError].} =
  # https://consensys.github.io/web3signer/web3signer-eth2.html#tag/Signing/operation/ETH2_SIGN
  # https://github.com/ConsenSys/web3signer/blob/d51337e96ba5ce410222943556bed7c4856b8e57/core/src/main/java/tech/pegasys/web3signer/core/service/http/handlers/signing/eth2/json/BlockRequestDeserializer.java#L42-L58
  writer.beginRecord()
  writer.writeField("version", value.kind.toString.toUpperAscii)
  writer.writeField("block_header", value.data)
  writer.endRecord()

## ForkedSignedBeaconBlock
proc readValue*(reader: var JsonReader[RestJson],
                value: var ForkedSignedBeaconBlock) {.
     raises: [IOError, SerializationError].} =
  var
    version: Opt[ConsensusFork]
    data: Opt[JsonString]

  for fieldName in readObjectFields(reader):
    case fieldName
    of "version":
      if version.isSome():
        reader.raiseUnexpectedField("Multiple version fields found",
                                    "ForkedSignedBeaconBlock")
      version = ConsensusFork.init(reader.readValue(string))
      if version.isNone:
        reader.raiseUnexpectedValue("Incorrect version field value")
    of "data":
      if data.isSome():
        reader.raiseUnexpectedField("Multiple data fields found",
                                    "ForkedSignedBeaconBlock")
      data = Opt.some(reader.readValue(JsonString))
    else:
      unrecognizedFieldWarning(fieldName, typeof(value).name)

  if version.isNone():
    reader.raiseUnexpectedValue("Field version is missing")
  if data.isNone():
    reader.raiseUnexpectedValue("Field data is missing")

  case version.get():
  of ConsensusFork.Phase0:
    let res =
      try:
        RestJson.decode(string(data.get()),
                        phase0.SignedBeaconBlock,
                        requireAllFields = true,
                        allowUnknownFields = true)
      except SerializationError:
        reader.raiseUnexpectedValue("Incorrect phase0 block format")

    value = ForkedSignedBeaconBlock.init(res)
  of ConsensusFork.Altair:
    let res =
      try:
        RestJson.decode(string(data.get()),
                        altair.SignedBeaconBlock,
                        requireAllFields = true,
                        allowUnknownFields = true)
      except SerializationError:
        reader.raiseUnexpectedValue("Incorrect altair block format")

    value = ForkedSignedBeaconBlock.init(res)
  of ConsensusFork.Bellatrix:
    let res =
      try:
        RestJson.decode(string(data.get()),
                        bellatrix.SignedBeaconBlock,
                        requireAllFields = true,
                        allowUnknownFields = true)
      except SerializationError:
        reader.raiseUnexpectedValue("Incorrect bellatrix block format")

    value = ForkedSignedBeaconBlock.init(res)
  of ConsensusFork.Capella:
    let res =
      try:
        RestJson.decode(string(data.get()),
                        capella.SignedBeaconBlock,
                        requireAllFields = true,
                        allowUnknownFields = true)
      except SerializationError:
        reader.raiseUnexpectedValue("Incorrect capella block format")

    value = ForkedSignedBeaconBlock.init(res)
  of ConsensusFork.Deneb:
    let res =
      try:
        RestJson.decode(string(data.get()),
                        deneb.SignedBeaconBlock,
                        requireAllFields = true,
                        allowUnknownFields = true)
      except SerializationError:
        reader.raiseUnexpectedValue("Incorrect deneb block format")

    value = ForkedSignedBeaconBlock.init(res)
  of ConsensusFork.Electra:
    let res =
      try:
        RestJson.decode(string(data.get()),
                        electra.SignedBeaconBlock,
                        requireAllFields = true,
                        allowUnknownFields = true)
      except SerializationError:
        reader.raiseUnexpectedValue("Incorrect electra block format")

    value = ForkedSignedBeaconBlock.init(res)
  of ConsensusFork.Fulu:
    let res =
      try:
        RestJson.decode(string(data.get()),
                        fulu.SignedBeaconBlock,
                        requireAllFields = true,
                        allowUnknownFields = true)
      except SerializationError:
        reader.raiseUnexpectedValue("Incorrect fulu block format")

    value = ForkedSignedBeaconBlock.init(res)
  withBlck(value):
    forkyBlck.root = hash_tree_root(forkyBlck.message)

proc writeValue*(
    writer: var JsonWriter[RestJson], value: ForkedSignedBeaconBlock
) {.raises: [IOError].} =
  writer.beginRecord()
  writer.writeField("version", value.kind.toString)
  case value.kind
  of ConsensusFork.Phase0:
    writer.writeField("data", value.phase0Data)
  of ConsensusFork.Altair:
    writer.writeField("data", value.altairData)
  of ConsensusFork.Bellatrix:
    writer.writeField("data", value.bellatrixData)
  of ConsensusFork.Capella:
    writer.writeField("data", value.capellaData)
  of ConsensusFork.Deneb:
    writer.writeField("data", value.denebData)
  of ConsensusFork.Electra:
    writer.writeField("data", value.electraData)
  of ConsensusFork.Fulu:
    writer.writeField("data", value.fuluData)
  writer.endRecord()

# ForkedHashedBeaconState is used where a `ForkedBeaconState` normally would
# be used, mainly because caching the hash early on is easier to do
proc readValue*(reader: var JsonReader[RestJson],
                value: var ForkedHashedBeaconState) {.
     raises: [IOError, SerializationError].} =
  var
    version: Opt[ConsensusFork]
    data: Opt[JsonString]

  for fieldName in readObjectFields(reader):
    case fieldName
    of "version":
      if version.isSome():
        reader.raiseUnexpectedField("Multiple version fields found",
                                    "ForkedBeaconState")
      version = ConsensusFork.init(reader.readValue(string))
      if version.isNone:
        reader.raiseUnexpectedValue("Incorrect version field value")
    of "data":
      if data.isSome():
        reader.raiseUnexpectedField("Multiple data fields found",
                                    "ForkedBeaconState")
      data = Opt.some(reader.readValue(JsonString))
    else:
      unrecognizedFieldWarning(fieldName, typeof(value).name)

  if version.isNone():
    reader.raiseUnexpectedValue("Field version is missing")
  if data.isNone():
    reader.raiseUnexpectedValue("Field data is missing")

  # Use a temporary to avoid stack instances and `value` mutation in case of
  # exception
  let
    tmp = (ref ForkedHashedBeaconState)(kind: version.get())

  template toValue(field: untyped) =
    if tmp[].kind == value.kind:
      assign(value.field, tmp[].field)
    else:
      value = tmp[] # slow, but rare (hopefully)
    value.field.root = hash_tree_root(value.field.data)

  case version.get():
  of ConsensusFork.Phase0:
    try:
      tmp[].phase0Data.data = RestJson.decode(
        string(data.get()),
        phase0.BeaconState,
        requireAllFields = true,
        allowUnknownFields = true)
    except SerializationError:
      reader.raiseUnexpectedValue("Incorrect phase0 beacon state format")

    toValue(phase0Data)
  of ConsensusFork.Altair:
    try:
      tmp[].altairData.data = RestJson.decode(
        string(data.get()),
        altair.BeaconState,
        requireAllFields = true,
        allowUnknownFields = true)
    except SerializationError:
      reader.raiseUnexpectedValue("Incorrect altair beacon state format")

    toValue(altairData)
  of ConsensusFork.Bellatrix:
    try:
      tmp[].bellatrixData.data = RestJson.decode(
        string(data.get()),
        bellatrix.BeaconState,
        requireAllFields = true,
        allowUnknownFields = true)
    except SerializationError:
      reader.raiseUnexpectedValue("Incorrect bellatrix beacon state format")
    toValue(bellatrixData)
  of ConsensusFork.Capella:
    try:
      tmp[].capellaData.data = RestJson.decode(
        string(data.get()),
        capella.BeaconState,
        requireAllFields = true,
        allowUnknownFields = true)
    except SerializationError:
      reader.raiseUnexpectedValue("Incorrect capella beacon state format")
    toValue(capellaData)
  of ConsensusFork.Deneb:
    try:
      tmp[].denebData.data = RestJson.decode(
        string(data.get()),
        deneb.BeaconState,
        requireAllFields = true,
        allowUnknownFields = true)
    except SerializationError:
      reader.raiseUnexpectedValue("Incorrect deneb beacon state format")
    toValue(denebData)
  of ConsensusFork.Electra:
    try:
      tmp[].electraData.data = RestJson.decode(
        string(data.get()),
        electra.BeaconState,
        requireAllFields = true,
        allowUnknownFields = true)
    except SerializationError:
      reader.raiseUnexpectedValue("Incorrect electra beacon state format")
    toValue(electraData)
  of ConsensusFork.Fulu:
    try:
      tmp[].fuluData.data = RestJson.decode(
        string(data.get()),
        fulu.BeaconState,
        requireAllFields = true,
        allowUnknownFields = true)
    except SerializationError:
      reader.raiseUnexpectedValue("Incorrect fulu beacon state format")
    toValue(fuluData)

proc writeValue*(
    writer: var JsonWriter[RestJson], value: ForkedHashedBeaconState
) {.raises: [IOError].} =
  writer.beginRecord()
  writer.writeField("version", value.kind.toString)
  case value.kind
  of ConsensusFork.Phase0:
    writer.writeField("data", value.phase0Data.data)
  of ConsensusFork.Altair:
    writer.writeField("data", value.altairData.data)
  of ConsensusFork.Bellatrix:
    writer.writeField("data", value.bellatrixData.data)
  of ConsensusFork.Capella:
    writer.writeField("data", value.capellaData.data)
  of ConsensusFork.Deneb:
    writer.writeField("data", value.denebData.data)
  of ConsensusFork.Electra:
    writer.writeField("data", value.electraData.data)
  of ConsensusFork.Fulu:
    writer.writeField("data", value.fuluData.data)
  writer.endRecord()

## SomeForkedLightClientObject
proc readValue*[T: SomeForkedLightClientObject](
    reader: var JsonReader[RestJson], value: var T) {.
    raises: [IOError, SerializationError].} =
  var
    version: Opt[ConsensusFork]
    data: Opt[JsonString]

  for fieldName in readObjectFields(reader):
    case fieldName
    of "version":
      if version.isSome:
        reader.raiseUnexpectedField("Multiple version fields found", T.name)
      let consensusFork =
        ConsensusFork.decodeString(reader.readValue(string)).valueOr:
          reader.raiseUnexpectedValue("Incorrect version field value")
      version.ok consensusFork
    of "data":
      if data.isSome:
        reader.raiseUnexpectedField("Multiple data fields found", T.name)
      data.ok reader.readValue(JsonString)
    else:
      unrecognizedFieldWarning(fieldName, typeof(value).name)

  if version.isNone:
    reader.raiseUnexpectedValue("Field version is missing")
  if data.isNone:
    reader.raiseUnexpectedValue("Field data is missing")

  withLcDataFork(lcDataForkAtConsensusFork(version.get)):
    when lcDataFork > LightClientDataFork.None:
      try:
        value = T.init(RestJson.decode(
          string(data.get()),
          T.Forky(lcDataFork),
          requireAllFields = true,
          allowUnknownFields = true))
      except SerializationError:
        reader.raiseUnexpectedValue("Incorrect format (" & $lcDataFork & ")")
    else:
      reader.raiseUnexpectedValue("Unsupported fork " & $version.get)

## ForkedAggregateAndProof
proc readValue*(reader: var JsonReader[RestJson],
                value: var ForkedAggregateAndProof) {.
     raises: [IOError, SerializationError].} =
  var
    version: Opt[ConsensusFork]
    data: Opt[JsonString]

  for fieldName {.inject.} in readObjectFields(reader):
    case fieldName
    of "version":
      if version.isSome():
        reader.raiseUnexpectedField("Multiple version fields found",
                                    "ForkedAggregateAndProof")
      let vres = reader.readValue(string).toLowerAscii()
      version = ConsensusFork.init(vres)
      if version.isNone():
        reader.raiseUnexpectedValue("Incorrect version field value")
    of "data":
      if data.isSome():
        reader.raiseUnexpectedField(
          "Multiple '" & fieldName & "' fields found",
          "ForkedAggregateAndProof")
      data = Opt.some(reader.readValue(JsonString))
    else:
      unrecognizedFieldWarning(fieldName, "ForkedAggregateAndProof")

  if version.isNone():
    reader.raiseUnexpectedValue("Field `version` is missing")
  if data.isNone():
    reader.raiseUnexpectedValue("Field `data` is missing")

  withConsensusFork(version.get()):
    when consensusFork < ConsensusFork.Electra:
      let res =
        try:
          RestJson.decode(string(data.get()),
                          phase0.AggregateAndProof,
                          requireAllFields = true,
                          allowUnknownFields = true)
        except SerializationError as exc:
          reader.raiseUnexpectedValue(
            "Incorrect phase0 aggregated attestation format, [" &
            exc.formatMsg("ForkedAggregateAndProof") & "]")
      value = ForkedAggregateAndProof.init(res, consensusFork)
    else:
      let res =
        try:
          RestJson.decode(string(data.get()),
                          electra.AggregateAndProof,
                          requireAllFields = true,
                          allowUnknownFields = true)
        except SerializationError as exc:
          reader.raiseUnexpectedValue(
            "Incorrect electra aggregated attestation format, [" &
            exc.formatMsg("ForkedAggregateAndProof") & "]")
      value = ForkedAggregateAndProof.init(res, consensusFork)

proc writeValue*(writer: var JsonWriter[RestJson],
                 proof: ForkedAggregateAndProof) {.raises: [IOError].} =
  writer.beginRecord()
  writer.writeField("version", proof.kind)
  withAggregateAndProof(proof):
    writer.writeField("data", forkyProof)
  writer.endRecord()

## Web3SignerRequest
proc writeValue*(
    writer: var JsonWriter[RestJson], value: Web3SignerRequest
) {.raises: [IOError].} =
  writer.beginRecord()
  case value.kind
  of Web3SignerRequestKind.AggregationSlot:
    doAssert(value.forkInfo.isSome(),
             "forkInfo should be set for this type of request")
    writer.writeField("type", "AGGREGATION_SLOT")
    writer.writeField("fork_info", value.forkInfo.get())
    if isSome(value.signingRoot):
      writer.writeField("signingRoot", value.signingRoot)
    writer.writeField("aggregation_slot", value.aggregationSlot)
  of Web3SignerRequestKind.AggregateAndProof:
    doAssert(value.forkInfo.isSome(),
             "forkInfo should be set for this type of request")
    writer.writeField("type", "AGGREGATE_AND_PROOF")
    writer.writeField("fork_info", value.forkInfo.get())
    if isSome(value.signingRoot):
      writer.writeField("signingRoot", value.signingRoot)
    writer.writeField("aggregate_and_proof", value.aggregateAndProof)
  of Web3SignerRequestKind.AggregateAndProofV2:
    doAssert(value.forkInfo.isSome(),
             "forkInfo should be set for this type of request")
    writer.writeField("type", "AGGREGATE_AND_PROOF_V2")
    writer.writeField("fork_info", value.forkInfo.get())
    if isSome(value.signingRoot):
      writer.writeField("signingRoot", value.signingRoot)
    writer.writeField("aggregate_and_proof", value.forkedAggregateAndProof)
  of Web3SignerRequestKind.Attestation:
    doAssert(value.forkInfo.isSome(),
             "forkInfo should be set for this type of request")
    writer.writeField("type", "ATTESTATION")
    writer.writeField("fork_info", value.forkInfo.get())
    if isSome(value.signingRoot):
      writer.writeField("signingRoot", value.signingRoot)
    writer.writeField("attestation", value.attestation)
  of Web3SignerRequestKind.BlockV2:
    doAssert(value.forkInfo.isSome(),
             "forkInfo should be set for this type of request")
    writer.writeField("type", "BLOCK_V2")
    writer.writeField("fork_info", value.forkInfo.get())
    if isSome(value.signingRoot):
      writer.writeField("signingRoot", value.signingRoot)

    # https://github.com/Consensys/web3signer/blob/2d956c019663ac70f60640d23196d1d321c1b1fa/core/src/main/resources/openapi-specs/eth2/signing/schemas.yaml#L483-L500
    writer.writeField("beacon_block", value.beaconBlockHeader)

    if isSome(value.proofs):
      writer.writeField("proofs", value.proofs.get())
  of Web3SignerRequestKind.Deposit:
    writer.writeField("type", "DEPOSIT")
    if isSome(value.signingRoot):
      writer.writeField("signingRoot", value.signingRoot)
    writer.writeField("deposit", value.deposit)
  of Web3SignerRequestKind.RandaoReveal:
    doAssert(value.forkInfo.isSome(),
             "forkInfo should be set for this type of request")
    writer.writeField("type", "RANDAO_REVEAL")
    writer.writeField("fork_info", value.forkInfo.get())
    if isSome(value.signingRoot):
      writer.writeField("signingRoot", value.signingRoot)
    writer.writeField("randao_reveal", value.randaoReveal)
  of Web3SignerRequestKind.VoluntaryExit:
    doAssert(value.forkInfo.isSome(),
             "forkInfo should be set for this type of request")
    writer.writeField("type", "VOLUNTARY_EXIT")
    writer.writeField("fork_info", value.forkInfo.get())
    if isSome(value.signingRoot):
      writer.writeField("signingRoot", value.signingRoot)
    writer.writeField("voluntary_exit", value.voluntaryExit)
  of Web3SignerRequestKind.SyncCommitteeMessage:
    doAssert(value.forkInfo.isSome(),
             "forkInfo should be set for this type of request")
    writer.writeField("type", "SYNC_COMMITTEE_MESSAGE")
    writer.writeField("fork_info", value.forkInfo.get())
    if isSome(value.signingRoot):
      writer.writeField("signingRoot", value.signingRoot)
    writer.writeField("sync_committee_message", value.syncCommitteeMessage)
  of Web3SignerRequestKind.SyncCommitteeSelectionProof:
    doAssert(value.forkInfo.isSome(),
             "forkInfo should be set for this type of request")
    writer.writeField("type", "SYNC_COMMITTEE_SELECTION_PROOF")
    writer.writeField("fork_info", value.forkInfo.get())
    if isSome(value.signingRoot):
      writer.writeField("signingRoot", value.signingRoot)
    writer.writeField("sync_aggregator_selection_data",
                      value.syncAggregatorSelectionData)
  of Web3SignerRequestKind.SyncCommitteeContributionAndProof:
    doAssert(value.forkInfo.isSome(),
             "forkInfo should be set for this type of request")
    writer.writeField("type", "SYNC_COMMITTEE_CONTRIBUTION_AND_PROOF")
    writer.writeField("fork_info", value.forkInfo.get())
    if isSome(value.signingRoot):
      writer.writeField("signingRoot", value.signingRoot)
    writer.writeField("contribution_and_proof",
                      value.syncCommitteeContributionAndProof)
  of Web3SignerRequestKind.ValidatorRegistration:
    # https://consensys.github.io/web3signer/web3signer-eth2.html#operation/ETH2_SIGN
    doAssert(value.forkInfo.isSome(),
             "forkInfo should be set for this type of request")
    writer.writeField("type", "VALIDATOR_REGISTRATION")
    writer.writeField("fork_info", value.forkInfo.get())
    if isSome(value.signingRoot):
      writer.writeField("signingRoot", value.signingRoot)
    writer.writeField("validator_registration", value.validatorRegistration)
  writer.endRecord()

proc readValue*(reader: var JsonReader[RestJson],
                value: var Web3SignerRequest) {.
     raises: [IOError, SerializationError].} =
  var
    requestKind: Opt[Web3SignerRequestKind]
    forkInfo: Opt[Web3SignerForkInfo]
    signingRoot: Opt[Eth2Digest]
    data: Opt[JsonString]
    proofs: seq[Web3SignerMerkleProof]
    dataName: string

  for fieldName in readObjectFields(reader):
    case fieldName
    of "type":
      if requestKind.isSome():
        reader.raiseUnexpectedField("Multiple `type` fields found",
                                    "Web3SignerRequest")
      let vres = reader.readValue(string)
      requestKind = Opt.some(
        case vres
        of "AGGREGATION_SLOT":
          Web3SignerRequestKind.AggregationSlot
        of "AGGREGATE_AND_PROOF":
          Web3SignerRequestKind.AggregateAndProof
        of "AGGREGATE_AND_PROOF_V2":
          Web3SignerRequestKind.AggregateAndProofV2
        of "ATTESTATION":
          Web3SignerRequestKind.Attestation
        of "BLOCK_V2":
          Web3SignerRequestKind.BlockV2
        of "DEPOSIT":
          Web3SignerRequestKind.Deposit
        of "RANDAO_REVEAL":
          Web3SignerRequestKind.RandaoReveal
        of "VOLUNTARY_EXIT":
          Web3SignerRequestKind.VoluntaryExit
        of "SYNC_COMMITTEE_MESSAGE":
          Web3SignerRequestKind.SyncCommitteeMessage
        of "SYNC_COMMITTEE_SELECTION_PROOF":
          Web3SignerRequestKind.SyncCommitteeSelectionProof
        of "SYNC_COMMITTEE_CONTRIBUTION_AND_PROOF":
          Web3SignerRequestKind.SyncCommitteeContributionAndProof
        of "VALIDATOR_REGISTRATION":
          Web3SignerRequestKind.ValidatorRegistration
        else:
          reader.raiseUnexpectedValue("Unexpected `type` value")
      )
    of "fork_info":
      if forkInfo.isSome():
        reader.raiseUnexpectedField("Multiple `fork_info` fields found",
                                    "Web3SignerRequest")
      forkInfo = Opt.some(reader.readValue(Web3SignerForkInfo))
    of "signingRoot":
      if signingRoot.isSome():
        reader.raiseUnexpectedField("Multiple `signingRoot` fields found",
                                    "Web3SignerRequest")
      signingRoot = Opt.some(reader.readValue(Eth2Digest))
    of "proofs":
      let newProofs = reader.readValue(seq[Web3SignerMerkleProof])
      proofs.add(newProofs)
    of "aggregation_slot", "aggregate_and_proof", "block", "beacon_block",
       "randao_reveal", "voluntary_exit", "sync_committee_message",
       "sync_aggregator_selection_data", "contribution_and_proof",
       "attestation", "deposit", "validator_registration":
      if data.isSome():
        reader.raiseUnexpectedField("Multiple data fields found",
                                    "Web3SignerRequest")
      dataName = fieldName
      data = Opt.some(reader.readValue(JsonString))

    else:
      unrecognizedFieldWarning(fieldName, typeof(value).name)

  if requestKind.isNone():
    reader.raiseUnexpectedValue("Field `type` is missing")

  value =
    case requestKind.get()
    of Web3SignerRequestKind.AggregationSlot:
      if dataName != "aggregation_slot":
        reader.raiseUnexpectedValue("Field `aggregation_slot` is missing")
      if forkInfo.isNone():
        reader.raiseUnexpectedValue("Field `fork_info` is missing")
      let data = decodeJsonString(Web3SignerAggregationSlotData,
                                  data.get()).valueOr:
        reader.raiseUnexpectedValue(
          "Incorrect field `aggregation_slot` format")
      Web3SignerRequest(kind: Web3SignerRequestKind.AggregationSlot,
        forkInfo: forkInfo, signingRoot: signingRoot, aggregationSlot: data
      )
    of Web3SignerRequestKind.AggregateAndProof:
      if dataName != "aggregate_and_proof":
        reader.raiseUnexpectedValue("Field `aggregate_and_proof` is missing")
      if forkInfo.isNone():
        reader.raiseUnexpectedValue("Field `fork_info` is missing")
      let data = decodeJsonString(phase0.AggregateAndProof, data.get()).valueOr:
        reader.raiseUnexpectedValue(
          "Incorrect field `aggregate_and_proof` format")
      Web3SignerRequest(
        kind: Web3SignerRequestKind.AggregateAndProof,
        forkInfo: forkInfo, signingRoot: signingRoot, aggregateAndProof: data
      )
    of Web3SignerRequestKind.AggregateAndProofV2:
      if dataName != "aggregate_and_proof":
        reader.raiseUnexpectedValue("Field `aggregate_and_proof` is missing")
      if forkInfo.isNone():
        reader.raiseUnexpectedValue("Field `fork_info` is missing")
      let data = decodeJsonString(ForkedAggregateAndProof, data.get()).valueOr:
        reader.raiseUnexpectedValue(
          "Incorrect field `aggregate_and_proof` format")
      Web3SignerRequest(
        kind: Web3SignerRequestKind.AggregateAndProofV2,
        forkInfo: forkInfo, signingRoot: signingRoot,
        forkedAggregateAndProof: data
      )
    of Web3SignerRequestKind.Attestation:
      if dataName != "attestation":
        reader.raiseUnexpectedValue("Field `attestation` is missing")
      if forkInfo.isNone():
        reader.raiseUnexpectedValue("Field `fork_info` is missing")
      let data = decodeJsonString(AttestationData, data.get()).valueOr:
        reader.raiseUnexpectedValue("Incorrect field `attestation` format")
      Web3SignerRequest(
        kind: Web3SignerRequestKind.Attestation,
        forkInfo: forkInfo, signingRoot: signingRoot, attestation: data
      )
    of Web3SignerRequestKind.BlockV2:
      # https://github.com/ConsenSys/web3signer/blob/41834a927088f1bde7a097e17d19e954d0058e54/core/src/main/resources/openapi-specs/eth2/signing/schemas.yaml#L421-L425 (branch v22.7.0)
      # It's the "beacon_block" field even when it's not a block, but a header
      if dataName != "beacon_block":
        reader.raiseUnexpectedValue("Field `beacon_block` is missing")
      if forkInfo.isNone():
        reader.raiseUnexpectedValue("Field `fork_info` is missing")
      let data = decodeJsonString(Web3SignerForkedBeaconBlock,
                                  data.get()).valueOr:
        reader.raiseUnexpectedValue("Incorrect field `beacon_block` format")
      if len(proofs) > 0:
        Web3SignerRequest(
          kind: Web3SignerRequestKind.BlockV2,
          forkInfo: forkInfo, signingRoot: signingRoot, beaconBlockHeader: data,
          proofs: Opt.some(proofs)
        )
      else:
        Web3SignerRequest(
          kind: Web3SignerRequestKind.BlockV2,
          forkInfo: forkInfo, signingRoot: signingRoot, beaconBlockHeader: data
        )
    of Web3SignerRequestKind.Deposit:
      if dataName != "deposit":
        reader.raiseUnexpectedValue("Field `deposit` is missing")
      let data = decodeJsonString(Web3SignerDepositData, data.get()).valueOr:
        reader.raiseUnexpectedValue("Incorrect field `deposit` format")
      Web3SignerRequest(
        kind: Web3SignerRequestKind.Deposit,
        signingRoot: signingRoot, deposit: data
      )
    of Web3SignerRequestKind.RandaoReveal:
      if dataName != "randao_reveal":
        reader.raiseUnexpectedValue("Field `randao_reveal` is missing")
      if forkInfo.isNone():
        reader.raiseUnexpectedValue("Field `fork_info` is missing")
      let data = decodeJsonString(Web3SignerRandaoRevealData,
                                  data.get()).valueOr:
        reader.raiseUnexpectedValue("Incorrect field `randao_reveal` format")
      Web3SignerRequest(
        kind: Web3SignerRequestKind.RandaoReveal,
        forkInfo: forkInfo, signingRoot: signingRoot, randaoReveal: data
      )
    of Web3SignerRequestKind.VoluntaryExit:
      if dataName != "voluntary_exit":
        reader.raiseUnexpectedValue("Field `voluntary_exit` is missing")
      if forkInfo.isNone():
        reader.raiseUnexpectedValue("Field `fork_info` is missing")
      let data = decodeJsonString(VoluntaryExit, data.get()).valueOr:
        reader.raiseUnexpectedValue("Incorrect field `voluntary_exit` format")
      Web3SignerRequest(
        kind: Web3SignerRequestKind.VoluntaryExit,
        forkInfo: forkInfo, signingRoot: signingRoot, voluntaryExit: data
      )
    of Web3SignerRequestKind.SyncCommitteeMessage:
      if dataName != "sync_committee_message":
        reader.raiseUnexpectedValue(
          "Field `sync_committee_message` is missing")
      if forkInfo.isNone():
        reader.raiseUnexpectedValue("Field `fork_info` is missing")
      let data = decodeJsonString(Web3SignerSyncCommitteeMessageData,
                                  data.get()).valueOr:
        reader.raiseUnexpectedValue(
          "Incorrect field `sync_committee_message` format")
      Web3SignerRequest(
        kind: Web3SignerRequestKind.SyncCommitteeMessage,
        forkInfo: forkInfo, signingRoot: signingRoot,
        syncCommitteeMessage: data
      )
    of Web3SignerRequestKind.SyncCommitteeSelectionProof:
      if dataName != "sync_aggregator_selection_data":
        reader.raiseUnexpectedValue(
          "Field `sync_aggregator_selection_data` is missing")
      if forkInfo.isNone():
        reader.raiseUnexpectedValue("Field `fork_info` is missing")
      let data = decodeJsonString(SyncAggregatorSelectionData,
                                  data.get()).valueOr:
        reader.raiseUnexpectedValue(
          "Incorrect field `sync_aggregator_selection_data` format")
      Web3SignerRequest(
        kind: Web3SignerRequestKind.SyncCommitteeSelectionProof,
        forkInfo: forkInfo, signingRoot: signingRoot,
        syncAggregatorSelectionData: data
      )
    of Web3SignerRequestKind.SyncCommitteeContributionAndProof:
      if dataName != "contribution_and_proof":
        reader.raiseUnexpectedValue(
          "Field `contribution_and_proof` is missing")
      if forkInfo.isNone():
        reader.raiseUnexpectedValue("Field `fork_info` is missing")
      let data = decodeJsonString(ContributionAndProof, data.get()).valueOr:
        reader.raiseUnexpectedValue(
          "Incorrect field `contribution_and_proof` format")
      Web3SignerRequest(
        kind: Web3SignerRequestKind.SyncCommitteeContributionAndProof,
        forkInfo: forkInfo, signingRoot: signingRoot,
        syncCommitteeContributionAndProof: data
      )
    of Web3SignerRequestKind.ValidatorRegistration:
      if dataName != "validator_registration":
        reader.raiseUnexpectedValue(
          "Field `validator_registration` is missing")
      if forkInfo.isNone():
        reader.raiseUnexpectedValue("Field `fork_info` is missing")
      let data = decodeJsonString(Web3SignerValidatorRegistration,
                                  data.get()).valueOr:
        reader.raiseUnexpectedValue(
          "Incorrect field `validator_registration` format")
      Web3SignerRequest(
        kind: Web3SignerRequestKind.ValidatorRegistration,
        forkInfo: forkInfo, signingRoot: signingRoot,
        validatorRegistration: data
      )

## RemoteKeystoreStatus
proc writeValue*(
    writer: var JsonWriter[RestJson], value: RemoteKeystoreStatus
) {.raises: [IOError].} =
  writer.beginRecord()
  writer.writeField("status", $value.status)
  if value.message.isSome():
    writer.writeField("message", value.message.get())
  writer.endRecord()

proc readValue*(reader: var JsonReader[RestJson],
                value: var RemoteKeystoreStatus) {.
     raises: [IOError, SerializationError].} =
  var message: Opt[string]
  var status: Opt[KeystoreStatus]

  for fieldName in readObjectFields(reader):
    case fieldName
    of "message":
      if message.isSome():
        reader.raiseUnexpectedField("Multiple `message` fields found",
                                    "RemoteKeystoreStatus")
      message = Opt.some(reader.readValue(string))
    of "status":
      if status.isSome():
        reader.raiseUnexpectedField("Multiple `status` fields found",
                                    "RemoteKeystoreStatus")
      let res = reader.readValue(string)
      status = Opt.some(
        case res
        of "error":
          KeystoreStatus.error
        of "not_active":
          KeystoreStatus.notActive
        of "not_found":
          KeystoreStatus.notFound
        of "deleted":
          KeystoreStatus.deleted
        of "duplicate":
          KeystoreStatus.duplicate
        of "imported":
          KeystoreStatus.imported
        else:
          reader.raiseUnexpectedValue("Invalid `status` value")
      )
    else:
      unrecognizedFieldWarning(fieldName, typeof(value).name)

  if status.isNone():
    reader.raiseUnexpectedValue("Field `status` is missing")

  value = RemoteKeystoreStatus(status: status.get(), message: message)

## ScryptSalt
proc readValue*(reader: var JsonReader[RestJson], value: var ScryptSalt) {.
     raises: [SerializationError, IOError].} =
  let res = ncrutils.fromHex(reader.readValue(string))
  if len(res) == 0:
    reader.raiseUnexpectedValue("Invalid scrypt salt value")
  value = ScryptSalt(res)

## Pbkdf2Params
proc writeValue*(
    writer: var JsonWriter[RestJson], value: Pbkdf2Params
) {.raises: [IOError].} =
  writer.beginRecord()
  writer.writeField("dklen", JsonString(Base10.toString(value.dklen)))
  writer.writeField("c", JsonString(Base10.toString(value.c)))
  writer.writeField("prf", value.prf)
  writer.writeField("salt", value.salt)
  writer.endRecord()

proc readValue*(reader: var JsonReader[RestJson], value: var Pbkdf2Params) {.
     raises: [SerializationError, IOError].} =
  var
    dklen: Opt[uint64]
    c: Opt[uint64]
    prf: Opt[PrfKind]
    salt: Opt[Pbkdf2Salt]

  for fieldName in readObjectFields(reader):
    case fieldName
    of "dklen":
      if dklen.isSome():
        reader.raiseUnexpectedField("Multiple `dklen` fields found",
                                    "Pbkdf2Params")
      dklen = Opt.some(reader.readValue(uint64))
    of "c":
      if c.isSome():
        reader.raiseUnexpectedField("Multiple `c` fields found",
                                    "Pbkdf2Params")
      c = Opt.some(reader.readValue(uint64))
    of "prf":
      if prf.isSome():
        reader.raiseUnexpectedField("Multiple `prf` fields found",
                                    "Pbkdf2Params")
      prf = Opt.some(reader.readValue(PrfKind))
    of "salt":
      if salt.isSome():
        reader.raiseUnexpectedField("Multiple `salt` fields found",
                                    "Pbkdf2Params")
      salt = Opt.some(reader.readValue(Pbkdf2Salt))
    else:
      unrecognizedFieldWarning(fieldName, typeof(value).name)

  if dklen.isNone():
    reader.raiseUnexpectedValue("Field `dklen` is missing")
  if c.isNone():
    reader.raiseUnexpectedValue("Field `c` is missing")
  if prf.isNone():
    reader.raiseUnexpectedValue("Field `prf` is missing")
  if salt.isNone():
    reader.raiseUnexpectedValue("Field `salt` is missing")

  value = Pbkdf2Params(
    dklen: dklen.get(),
    c: c.get(),
    prf: prf.get(),
    salt: salt.get()
  )

## ScryptParams
proc writeValue*(
    writer: var JsonWriter[RestJson], value: ScryptParams
) {.raises: [IOError].} =
  writer.beginRecord()
  writer.writeField("dklen", JsonString(Base10.toString(value.dklen)))
  writer.writeField("n", JsonString(Base10.toString(uint64(value.n))))
  writer.writeField("p", JsonString(Base10.toString(uint64(value.p))))
  writer.writeField("r", JsonString(Base10.toString(uint64(value.r))))
  writer.writeField("salt", value.salt)
  writer.endRecord()

proc readValue*(reader: var JsonReader[RestJson], value: var ScryptParams) {.
     raises: [SerializationError, IOError].} =
  var
    dklen: Opt[uint64]
    n, p, r: Opt[int]
    salt: Opt[ScryptSalt]

  for fieldName in readObjectFields(reader):
    case fieldName
    of "dklen":
      if dklen.isSome():
        reader.raiseUnexpectedField("Multiple `dklen` fields found",
                                    "ScryptParams")
      dklen = Opt.some(reader.readValue(uint64))
    of "n":
      if n.isSome():
        reader.raiseUnexpectedField("Multiple `n` fields found",
                                    "ScryptParams")
      let res = reader.readValue(int)
      if res < 0:
        reader.raiseUnexpectedValue("Unexpected negative `n` value")
      n = Opt.some(res)
    of "p":
      if p.isSome():
        reader.raiseUnexpectedField("Multiple `p` fields found",
                                    "ScryptParams")
      let res = reader.readValue(int)
      if res < 0:
        reader.raiseUnexpectedValue("Unexpected negative `p` value")
      p = Opt.some(res)
    of "r":
      if r.isSome():
        reader.raiseUnexpectedField("Multiple `r` fields found",
                                    "ScryptParams")
      let res = reader.readValue(int)
      if res < 0:
        reader.raiseUnexpectedValue("Unexpected negative `r` value")
      r = Opt.some(res)
    of "salt":
      if salt.isSome():
        reader.raiseUnexpectedField("Multiple `salt` fields found",
                                    "ScryptParams")
      salt = Opt.some(reader.readValue(ScryptSalt))
    else:
      unrecognizedFieldWarning(fieldName, typeof(value).name)

  if dklen.isNone():
    reader.raiseUnexpectedValue("Field `dklen` is missing")
  if n.isNone():
    reader.raiseUnexpectedValue("Field `n` is missing")
  if p.isNone():
    reader.raiseUnexpectedValue("Field `p` is missing")
  if r.isNone():
    reader.raiseUnexpectedValue("Field `r` is missing")
  if salt.isNone():
    reader.raiseUnexpectedValue("Field `salt` is missing")

  value = ScryptParams(
    dklen: dklen.get(),
    n: n.get(), p: p.get(), r: r.get(),
    salt: salt.get()
  )

## Keystore
proc writeValue*(
    writer: var JsonWriter[RestJson], value: Keystore
) {.error: "keystores must be converted to json with Json.encode(keystore). " &
           "There is no REST-specific encoding" .}

proc readValue*(reader: var JsonReader[RestJson], value: var Keystore) {.
     error: "Keystores must be loaded with `parseKeystore`. " &
            "There is no REST-specific encoding".}

## KeystoresAndSlashingProtection
proc writeValue*(
    writer: var JsonWriter[RestJson], value: KeystoresAndSlashingProtection
) {.raises: [IOError].} =
  writer.beginRecord()
  let keystores =
    block:
      var res: seq[string]
      for keystore in value.keystores:
        let encoded = Json.encode(keystore)
        res.add(encoded)
      res
  writer.writeField("keystores", keystores)
  writer.writeField("passwords", value.passwords)
  if value.slashing_protection.isSome():
    let slashingProtection = RestJson.encode(value.slashing_protection.get)
    writer.writeField("slashing_protection", slashingProtection)
  writer.endRecord()

proc readValue*(reader: var JsonReader[RestJson],
                value: var KeystoresAndSlashingProtection) {.
     raises: [SerializationError, IOError].} =
  var
    strKeystores: seq[string]
    passwords: seq[string]
    strSlashing: Opt[string]

  for fieldName in readObjectFields(reader):
    case fieldName
    of "keystores":
      strKeystores = reader.readValue(seq[string])
    of "passwords":
      passwords = reader.readValue(seq[string])
    of "slashing_protection":
      if strSlashing.isSome():
        reader.raiseUnexpectedField(
          "Multiple `slashing_protection` fields found",
          "KeystoresAndSlashingProtection")
      strSlashing = Opt.some(reader.readValue(string))
    else:
      unrecognizedFieldWarning(fieldName, typeof(value).name)

  if len(strKeystores) == 0:
    reader.raiseUnexpectedValue("Missing or empty `keystores` value")
  if len(passwords) == 0:
    reader.raiseUnexpectedValue("Missing or empty `passwords` value")

  let keystores =
    block:
      var res: seq[Keystore]
      for item in strKeystores:
        let key =
          try:
            parseKeystore(item)
          except SerializationError:
            # TODO re-raise the exception by adjusting the column index, so the user
            # will get an accurate syntax error within the larger message
            reader.raiseUnexpectedValue("Invalid keystore format")
        res.add(key)
      res

  let slashing =
    if strSlashing.isSome():
      let db =
        try:
          RestJson.decode(strSlashing.get(),
                          SPDIR,
                          requireAllFields = true,
                          allowUnknownFields = true)
        except SerializationError:
          reader.raiseUnexpectedValue("Invalid slashing protection format")
      Opt.some(db)
    else:
      Opt.none(SPDIR)

  value = KeystoresAndSlashingProtection(
    keystores: keystores, passwords: passwords, slashing_protection: slashing
  )

## RestActivityItem
proc writeValue*(
    writer: var JsonWriter[RestJson], value: RestActivityItem
) {.raises: [IOError].} =
  writer.beginRecord()
  writer.writeField("index", value.index)
  writer.writeField("epoch", value.epoch)
  writer.writeField("active", value.active)
  writer.endRecord()

proc readValue*(reader: var JsonReader[RestJson],
                value: var RestActivityItem) {.
     raises: [SerializationError, IOError].} =
  var index: Opt[ValidatorIndex]
  var epoch: Opt[Epoch]
  var active: Opt[bool]

  for fieldName in readObjectFields(reader):
    case fieldName
    of "index":
      if index.isSome():
        reader.raiseUnexpectedField(
          "Multiple `index` fields found", "RestActivityItem")
      index = Opt.some(reader.readValue(ValidatorIndex))
    of "epoch":
      if epoch.isSome():
        reader.raiseUnexpectedField(
          "Multiple `epoch` fields found", "RestActivityItem")
      epoch = Opt.some(reader.readValue(Epoch))
    of "active":
      if active.isSome():
        reader.raiseUnexpectedField(
          "Multiple `active` fields found", "RestActivityItem")
      active = Opt.some(reader.readValue(bool))
    else:
      unrecognizedFieldIgnore()

  if index.isNone():
    reader.raiseUnexpectedValue("Missing or empty `index` value")
  if epoch.isNone():
    reader.raiseUnexpectedValue("Missing or empty `epoch` value")
  if active.isNone():
    reader.raiseUnexpectedValue("Missing or empty `active` value")

  value = RestActivityItem(index: index.get(), epoch: epoch.get(),
                           active: active.get())

## RestLivenessItem
proc writeValue*(
    writer: var JsonWriter[RestJson], value: RestLivenessItem
) {.raises: [IOError].} =
  writer.beginRecord()
  writer.writeField("index", value.index)
  writer.writeField("is_live", value.is_live)
  writer.endRecord()

proc readValue*(reader: var JsonReader[RestJson],
                value: var RestLivenessItem) {.
     raises: [SerializationError, IOError].} =
  var index: Opt[ValidatorIndex]
  var isLive: Opt[bool]

  for fieldName in readObjectFields(reader):
    case fieldName
    of "index":
      if index.isSome():
        reader.raiseUnexpectedField(
          "Multiple `index` fields found", "RestLivenessItem")
      index = Opt.some(reader.readValue(ValidatorIndex))
    of "is_live":
      if isLive.isSome():
        reader.raiseUnexpectedField(
          "Multiple `is_live` fields found", "RestLivenessItem")
      isLive = Opt.some(reader.readValue(bool))
    else:
      unrecognizedFieldIgnore()

  if index.isNone():
    reader.raiseUnexpectedValue("Missing or empty `index` value")
  if isLive.isNone():
    reader.raiseUnexpectedValue("Missing or empty `is_live` value")

  value = RestLivenessItem(index: index.get(), is_live: isLive.get())

## HeadChangeInfoObject
proc writeValue*(
    writer: var JsonWriter[RestJson], value: HeadChangeInfoObject
) {.raises: [IOError].} =
  writer.beginRecord()
  writer.writeField("slot", value.slot)
  writer.writeField("block", value.block_root)
  writer.writeField("state", value.state_root)
  writer.writeField("epoch_transition", value.epoch_transition)
  writer.writeField("previous_duty_dependent_root",
                    value.previous_duty_dependent_root)
  writer.writeField("current_duty_dependent_root",
                    value.current_duty_dependent_root)
  if value.optimistic.isSome():
    writer.writeField("execution_optimistic", value.optimistic.get())
  writer.endRecord()

## ReorgInfoObject
proc writeValue*(
    writer: var JsonWriter[RestJson], value: ReorgInfoObject
) {.raises: [IOError].} =
  writer.beginRecord()
  writer.writeField("slot", value.slot)
  writer.writeField("depth", value.depth)
  writer.writeField("old_head_block", value.old_head_block)
  writer.writeField("new_head_block", value.new_head_block)
  writer.writeField("old_head_state", value.old_head_state)
  writer.writeField("new_head_state", value.new_head_state)
  if value.optimistic.isSome():
    writer.writeField("execution_optimistic", value.optimistic.get())
  writer.endRecord()

## FinalizationInfoObject
proc writeValue*(
    writer: var JsonWriter[RestJson], value: FinalizationInfoObject
) {.raises: [IOError].} =
  writer.beginRecord()
  writer.writeField("block", value.block_root)
  writer.writeField("state", value.state_root)
  writer.writeField("epoch", value.epoch)
  if value.optimistic.isSome():
    writer.writeField("execution_optimistic", value.optimistic.get())
  writer.endRecord()

## RestNodeValidity
proc writeValue*(
    writer: var JsonWriter[RestJson], value: RestNodeValidity
) {.raises: [IOError].} =
  writer.writeValue($value)

## RestErrorMessage
proc readValue*(reader: var JsonReader[RestJson],
                value: var RestErrorMessage) {.
     raises: [SerializationError, IOError].} =
  var
    code: Opt[int]
    message: Opt[string]
    stacktraces: Opt[seq[string]]

  for fieldName in readObjectFields(reader):
    case fieldName
    of "code":
      if code.isSome():
        reader.raiseUnexpectedField("Multiple `code` fields found",
                                    "RestErrorMessage")
      let ires =
        try:
          let res = reader.readValue(int)
          if res < 0:
            reader.raiseUnexpectedValue("Invalid `code` field value")
          Opt.some(res)
        except SerializationError:
          Opt.none(int)
      if ires.isNone():
        let sres =
          try: parseInt(reader.readValue(string))
          except ValueError:
            reader.raiseUnexpectedValue("Invalid `code` field format")
        if sres < 0:
          reader.raiseUnexpectedValue("Invalid `code` field value")
        code = Opt.some(sres)
      else:
        code = ires
    of "message":
      if message.isSome():
        reader.raiseUnexpectedField("Multiple `message` fields found",
                                    "RestErrorMessage")
      message = Opt.some(reader.readValue(string))
    of "stacktraces":
      if stacktraces.isSome():
        reader.raiseUnexpectedField("Multiple `stacktraces` fields found",
                                    "RestErrorMessage")
      stacktraces = Opt.some(reader.readValue(seq[string]))
    else:
      unrecognizedFieldIgnore()

  if code.isNone():
    reader.raiseUnexpectedValue("Missing or invalid `code` value")
  if message.isNone():
    reader.raiseUnexpectedValue("Missing or invalid `message` value")

  value = RestErrorMessage(
    code: code.get(), message: message.get(),
    stacktraces: stacktraces
  )

proc writeValue*(writer: var JsonWriter[RestJson], value: RestErrorMessage) {.
     raises: [IOError].} =
  writer.beginRecord()
  writer.writeField("code", value.code)
  writer.writeField("message", value.message)
  if value.stacktraces.isSome():
    writer.writeField("stacktraces", value.stacktraces.get())
  writer.endRecord()

## VCRuntimeConfig
proc readValue*(reader: var JsonReader[RestJson],
                value: var VCRuntimeConfig) {.
     raises: [SerializationError, IOError].} =
  for fieldName in readObjectFields(reader):
    let fieldValue = reader.readValue(string)
    if value.hasKeyOrPut(toUpperAscii(fieldName), fieldValue):
      let msg = "Multiple `" & fieldName & "` fields found"
      reader.raiseUnexpectedField(msg, "VCRuntimeConfig")

## ForkedMaybeBlindedBeaconBlock
proc writeValue*(writer: var JsonWriter[RestJson],
                 value: ProduceBlockResponseV3) {.raises: [IOError].} =
  writer.beginRecord()
  withForkyMaybeBlindedBlck(value):
    writer.writeField("version", consensusFork.toString())
    writer.writeField("execution_payload_blinded", isBlinded)
    if value.executionValue.isSome():
      writer.writeField("execution_payload_value",
                        $(value.executionValue.get()))
    if value.consensusValue.isSome():
      writer.writeField("consensus_block_value",
                        $(value.consensusValue.get()))
    writer.writeField("data", forkyMaybeBlindedBlck)
  writer.endRecord()

proc readValue*(reader: var JsonReader[RestJson],
                value: var ProduceBlockResponseV3) {.
     raises: [SerializationError, IOError].} =
  var
    version: Opt[ConsensusFork]
    blinded: Opt[bool]
    executionValue: Opt[UInt256]
    consensusValue: Opt[UInt256]
    data: Opt[JsonString]

  prepareForkedBlockReading(ProduceBlockResponseV3, reader, version, data,
                            blinded, executionValue, consensusValue)

  if blinded.isNone():
    reader.raiseUnexpectedValue("Field `execution_payload_blinded` is missing")
  if executionValue.isNone():
    reader.raiseUnexpectedValue("Field `execution_payload_value` is missing")
  # TODO (cheatfate): At some point we should add check for missing
  # `consensus_block_value` too
  if data.isNone():
    reader.raiseUnexpectedValue("Field `data` is missing")

  withConsensusFork(version.get):
    when consensusFork >= ConsensusFork.Deneb:
      if blinded.get:
        value = ForkedMaybeBlindedBeaconBlock.init(
          RestJson.decode(
            string(data.get()), consensusFork.BlindedBlockContents,
            requireAllFields = true, allowUnknownFields = true),
          executionValue, consensusValue)
      else:
        value = ForkedMaybeBlindedBeaconBlock.init(
          RestJson.decode(
            string(data.get()), consensusFork.BlockContents,
            requireAllFields = true, allowUnknownFields = true),
          executionValue, consensusValue)
    elif consensusFork >= ConsensusFork.Bellatrix:
      if blinded.get:
        reader.raiseUnexpectedValue(
          "`execution_payload_blinded` unsupported for `version`")
      value = ForkedMaybeBlindedBeaconBlock.init(
        RestJson.decode(
          string(data.get()), consensusFork.BlockContents,
          requireAllFields = true, allowUnknownFields = true),
        executionValue, consensusValue)
    else:
      if blinded.get:
        reader.raiseUnexpectedValue(
          "`execution_payload_blinded` unsupported for `version`")
      value = ForkedMaybeBlindedBeaconBlock.init(
        RestJson.decode(
          string(data.get()), consensusFork.BlockContents,
          requireAllFields = true, allowUnknownFields = true))

proc parseRoot(value: string): Result[Eth2Digest, cstring] =
  try:
    ok(Eth2Digest(data: hexToByteArray[32](value)))
  except ValueError:
    err("Unable to decode root value")

## GraffitiString
proc writeValue*(writer: var JsonWriter[RestJson], value: GraffitiString) {.
     raises: [IOError].} =
  writeValue(writer, $value)

proc readValue*(reader: var JsonReader[RestJson], T: type GraffitiString): T {.
     raises: [IOError, SerializationError].} =
  let res = init(GraffitiString, reader.readValue(string))
  if res.isErr():
    reader.raiseUnexpectedValue res.error
  res.get

proc decodeBody*(
       t: typedesc[RestPublishedSignedBeaconBlock],
       body: ContentBody,
       version: string
     ): Result[RestPublishedSignedBeaconBlock, RestErrorMessage] =
  if body.contentType == ApplicationJsonMediaType:
    let consensusFork = ConsensusFork.decodeString(version).valueOr:
      return err(RestErrorMessage.init(Http400, UnableDecodeVersionError,
                                       [version, $error]))

    template getBlck(blckType: untyped): untyped =
      try:
        RestPublishedSignedBeaconBlock(ForkedSignedBeaconBlock.init(
          RestJson.decode(body.data, blckType,
                          requireAllFields = true,
                          allowUnknownFields = true)))
      except SerializationError as exc:
        debug "Failed to decode JSON data",
              err = exc.formatMsg("<data>"),
              data = string.fromBytes(body.data)
        return err(RestErrorMessage.init(Http400, UnableDecodeError,
                                         [version, exc.formatMsg("<data>")]))
      except CatchableError as exc:
        return err(RestErrorMessage.init(Http400, UnexpectedDecodeError,
                                         [version, $exc.msg]))

    withConsensusFork(consensusFork):
      ok(getBlck(consensusFork.SignedBeaconBlock))

  elif body.contentType == OctetStreamMediaType:
    let consensusFork = ConsensusFork.decodeString(version).valueOr:
      return err(RestErrorMessage.init(Http400, UnableDecodeVersionError,
                                       [version, $error]))
    case consensusFork
    of ConsensusFork.Phase0:
      let blck =
        try:
          SSZ.decode(body.data, phase0.SignedBeaconBlock)
        except SerializationError as exc:
          return err(RestErrorMessage.init(Http400, UnableDecodeError,
                                           [version, exc.formatMsg("<data>")]))
        except CatchableError as exc:
          return err(RestErrorMessage.init(Http400, UnexpectedDecodeError,
                                           [version, $exc.msg]))
      ok(RestPublishedSignedBeaconBlock(ForkedSignedBeaconBlock.init(blck)))
    of ConsensusFork.Altair:
      let blck =
        try:
          SSZ.decode(body.data, altair.SignedBeaconBlock)
        except SerializationError as exc:
          return err(RestErrorMessage.init(Http400, UnableDecodeError,
                                           [version, exc.formatMsg("<data>")]))
        except CatchableError as exc:
          return err(RestErrorMessage.init(Http400, UnexpectedDecodeError,
                                           [version, $exc.msg]))
      ok(RestPublishedSignedBeaconBlock(ForkedSignedBeaconBlock.init(blck)))
    of ConsensusFork.Bellatrix:
      let blck =
        try:
          SSZ.decode(body.data, bellatrix.SignedBeaconBlock)
        except SerializationError as exc:
          return err(RestErrorMessage.init(Http400, UnableDecodeError,
                                           [version, exc.formatMsg("<data>")]))
        except CatchableError as exc:
          return err(RestErrorMessage.init(Http400, UnexpectedDecodeError,
                                           [version, $exc.msg]))
      ok(RestPublishedSignedBeaconBlock(ForkedSignedBeaconBlock.init(blck)))
    of ConsensusFork.Capella:
      let blck =
        try:
          SSZ.decode(body.data, capella.SignedBeaconBlock)
        except SerializationError as exc:
          return err(RestErrorMessage.init(Http400, UnableDecodeError,
                                           [version, exc.formatMsg("<data>")]))
        except CatchableError as exc:
          return err(RestErrorMessage.init(Http400, UnexpectedDecodeError,
                                           [version, $exc.msg]))
      ok(RestPublishedSignedBeaconBlock(ForkedSignedBeaconBlock.init(blck)))
    of ConsensusFork.Deneb:
      let blck =
        try:
          SSZ.decode(body.data, deneb.SignedBeaconBlock)
        except SerializationError as exc:
          return err(RestErrorMessage.init(Http400, UnableDecodeError,
                                           [version, exc.formatMsg("<data>")]))
        except CatchableError as exc:
          return err(RestErrorMessage.init(Http400, UnexpectedDecodeError,
                                           [version, $exc.msg]))
      ok(RestPublishedSignedBeaconBlock(ForkedSignedBeaconBlock.init(blck)))
    of ConsensusFork.Electra:
      let blck =
        try:
          SSZ.decode(body.data, electra.SignedBeaconBlock)
        except SerializationError as exc:
          return err(RestErrorMessage.init(Http400, UnableDecodeError,
                                           [version, exc.formatMsg("<data>")]))
        except CatchableError as exc:
          return err(RestErrorMessage.init(Http400, UnexpectedDecodeError,
                                           [version, $exc.msg]))
      ok(RestPublishedSignedBeaconBlock(ForkedSignedBeaconBlock.init(blck)))
    of ConsensusFork.Fulu:
      let blck =
        try:
          SSZ.decode(body.data, fulu.SignedBeaconBlock)
        except SerializationError as exc:
          return err(RestErrorMessage.init(Http400, UnableDecodeError,
                                           [version, exc.formatMsg("<data>")]))
        except CatchableError as exc:
          return err(RestErrorMessage.init(Http400, UnexpectedDecodeError,
                                           [version, $exc.msg]))
      ok(RestPublishedSignedBeaconBlock(ForkedSignedBeaconBlock.init(blck)))
  else:
    err(RestErrorMessage.init(Http415, "Invalid content type",
                              [version, $body.contentType]))

proc decodeBody*(
       t: typedesc[RestPublishedSignedBlockContents],
       body: ContentBody,
       version: string
     ): Result[RestPublishedSignedBlockContents, RestErrorMessage] =
  if body.contentType == ApplicationJsonMediaType:
    let consensusFork = ConsensusFork.decodeString(version).valueOr:
      return err(RestErrorMessage.init(Http400, UnableDecodeVersionError,
                                       [version, $error]))

    template getBlck(blckType: untyped): untyped =
      try:
        var res = RestJson.decode(body.data, blckType,
                                  requireAllFields = true,
                                  allowUnknownFields = true)
        when compiles(res.signed_block.messsage):
          {.error: "Deneb and later forks handled in case statement".}
        else:
          RestPublishedSignedBlockContents.init(
            res.message, hash_tree_root(res.message), res.signature)
      except SerializationError as exc:
        debug "Failed to decode JSON data",
              err = exc.formatMsg("<data>"),
              data = string.fromBytes(body.data)
        return err(RestErrorMessage.init(Http400, UnableDecodeError,
                                         [version, exc.formatMsg("<data>")]))
      except CatchableError as exc:
        return err(RestErrorMessage.init(Http400, UnexpectedDecodeError,
                                         [version, $exc.msg]))

    let data =
      case consensusFork
      of ConsensusFork.Phase0:    getBlck(phase0.SignedBeaconBlock)
      of ConsensusFork.Altair:    getBlck(altair.SignedBeaconBlock)
      of ConsensusFork.Bellatrix: getBlck(bellatrix.SignedBeaconBlock)
      of ConsensusFork.Capella:   getBlck(capella.SignedBeaconBlock)
      of ConsensusFork.Deneb:
        try:
          var res = RestJson.decode(body.data, DenebSignedBlockContents,
                                    requireAllFields = true,
                                    allowUnknownFields = true)
          res.signed_block.root = hash_tree_root(res.signed_block.message)
          RestPublishedSignedBlockContents(
            kind: ConsensusFork.Deneb, denebData: res)
        except SerializationError as exc:
          debug "Failed to decode JSON data",
                err = exc.formatMsg("<data>"),
                data = string.fromBytes(body.data)
          return err(RestErrorMessage.init(Http400, UnableDecodeError,
                                           [version, exc.formatMsg("<data>")]))
        except CatchableError as exc:
          return err(RestErrorMessage.init(Http400, UnexpectedDecodeError,
                                           [version, $exc.msg]))
      of ConsensusFork.Electra:
        try:
          var res = RestJson.decode(body.data, ElectraSignedBlockContents,
                                    requireAllFields = true,
                                    allowUnknownFields = true)
          res.signed_block.root = hash_tree_root(res.signed_block.message)
          RestPublishedSignedBlockContents(
            kind: ConsensusFork.Electra, electraData: res)
        except SerializationError as exc:
          debug "Failed to decode JSON data",
                err = exc.formatMsg("<data>"),
                data = string.fromBytes(body.data)
          return err(RestErrorMessage.init(Http400, UnableDecodeError,
                                           [version, exc.formatMsg("<data>")]))
        except CatchableError as exc:
          return err(RestErrorMessage.init(Http400, UnexpectedDecodeError,
                                           [version, $exc.msg]))
      of ConsensusFork.Fulu:
        try:
          var res = RestJson.decode(body.data, FuluSignedBlockContents,
                                    requireAllFields = true,
                                    allowUnknownFields = true)
          res.signed_block.root = hash_tree_root(res.signed_block.message)
          RestPublishedSignedBlockContents(
            kind: ConsensusFork.Fulu, fuluData: res)
        except SerializationError as exc:
          debug "Failed to decode JSON data",
                err = exc.formatMsg("<data>"),
                data = string.fromBytes(body.data)
          return err(RestErrorMessage.init(Http400, UnableDecodeError,
                                           [version, exc.formatMsg("<data>")]))
        except CatchableError as exc:
          return err(RestErrorMessage.init(Http400, UnexpectedDecodeError,
                                           [version, $exc.msg]))

    ok(data)
  elif body.contentType == OctetStreamMediaType:
    let consensusFork = ConsensusFork.decodeString(version).valueOr:
      return err(RestErrorMessage.init(Http400, UnableDecodeVersionError,
                                       [version, $error]))
    case consensusFork
    of ConsensusFork.Phase0:
      let blck =
        try:
          var res = SSZ.decode(body.data, phase0.SignedBeaconBlock)
          res.root = hash_tree_root(res.message)
          res
        except SerializationError as exc:
          return err(RestErrorMessage.init(Http400, UnableDecodeError,
                                           [version, exc.formatMsg("<data>")]))
        except CatchableError as exc:
          return err(RestErrorMessage.init(Http400, UnexpectedDecodeError,
                                           [version, $exc.msg]))
      ok(RestPublishedSignedBlockContents(
        kind: ConsensusFork.Phase0, phase0Data: blck))
    of ConsensusFork.Altair:
      let blck =
        try:
          var res = SSZ.decode(body.data, altair.SignedBeaconBlock)
          res.root = hash_tree_root(res.message)
          res
        except SerializationError as exc:
          return err(RestErrorMessage.init(Http400, UnableDecodeError,
                                           [version, exc.formatMsg("<data>")]))
        except CatchableError as exc:
          return err(RestErrorMessage.init(Http400, UnexpectedDecodeError,
                                           [version, $exc.msg]))
      ok(RestPublishedSignedBlockContents(
        kind: ConsensusFork.Altair, altairData: blck))
    of ConsensusFork.Bellatrix:
      let blck =
        try:
          var res = SSZ.decode(body.data, bellatrix.SignedBeaconBlock)
          res.root = hash_tree_root(res.message)
          res
        except SerializationError as exc:
          return err(RestErrorMessage.init(Http400, UnableDecodeError,
                                           [version, exc.formatMsg("<data>")]))
        except CatchableError as exc:
          return err(RestErrorMessage.init(Http400, UnexpectedDecodeError,
                                           [version, $exc.msg]))
      ok(RestPublishedSignedBlockContents(
        kind: ConsensusFork.Bellatrix, bellatrixData: blck))
    of ConsensusFork.Capella:
      let blck =
        try:
          var res = SSZ.decode(body.data, capella.SignedBeaconBlock)
          res.root = hash_tree_root(res.message)
          res
        except SerializationError as exc:
          return err(RestErrorMessage.init(Http400, UnableDecodeError,
                                           [version, exc.formatMsg("<data>")]))
        except CatchableError as exc:
          return err(RestErrorMessage.init(Http400, UnexpectedDecodeError,
                                           [version, $exc.msg]))
      ok(RestPublishedSignedBlockContents(
        kind: ConsensusFork.Capella, capellaData: blck))
    of ConsensusFork.Deneb:
      let blckContents =
        try:
          var res = SSZ.decode(body.data, DenebSignedBlockContents)
          res.signed_block.root = hash_tree_root(res.signed_block.message)
          res
        except SerializationError as exc:
          return err(RestErrorMessage.init(Http400, UnableDecodeError,
                                           [version, exc.formatMsg("<data>")]))
        except CatchableError as exc:
          return err(RestErrorMessage.init(Http400, UnexpectedDecodeError,
                                           [version, $exc.msg]))
      ok(RestPublishedSignedBlockContents(
        kind: ConsensusFork.Deneb, denebData: blckContents))
    of ConsensusFork.Electra:
      let blckContents =
        try:
          var res = SSZ.decode(body.data, ElectraSignedBlockContents)
          res.signed_block.root = hash_tree_root(res.signed_block.message)
          res
        except SerializationError as exc:
          return err(RestErrorMessage.init(Http400, UnableDecodeError,
                                           [version, exc.formatMsg("<data>")]))
        except CatchableError as exc:
          return err(RestErrorMessage.init(Http400, UnexpectedDecodeError,
                                           [version, $exc.msg]))
      ok(RestPublishedSignedBlockContents(
        kind: ConsensusFork.Electra, electraData: blckContents))
    of ConsensusFork.Fulu:
      let blckContents =
        try:
          var res = SSZ.decode(body.data, FuluSignedBlockContents)
          res.signed_block.root = hash_tree_root(res.signed_block.message)
          res
        except SerializationError as exc:
          return err(RestErrorMessage.init(Http400, UnableDecodeError,
                                           [version, exc.formatMsg("<data>")]))
        except CatchableError as exc:
          return err(RestErrorMessage.init(Http400, UnexpectedDecodeError,
                                           [version, $exc.msg]))
      ok(RestPublishedSignedBlockContents(
        kind: ConsensusFork.Fulu, fuluData: blckContents))
  else:
    err(RestErrorMessage.init(Http415, "Invalid content type",
                              [version, $body.contentType]))

proc decodeBody*[T](t: typedesc[T],
                    body: ContentBody): Result[T, cstring] =
  if body.contentType != ApplicationJsonMediaType:
    return err("Unsupported content type")
  let data =
    try:
      RestJson.decode(body.data, T,
                      requireAllFields = true,
                      allowUnknownFields = true)
    except SerializationError as exc:
      debug "Failed to deserialize REST JSON data",
            err = exc.formatMsg("<data>"),
            data = string.fromBytes(body.data)
      return err("Unable to deserialize data")
    except CatchableError:
      return err("Unexpected deserialization error")
  ok(data)

proc decodeBodyJsonOrSsz*[T](t: typedesc[T],
                             body: ContentBody): Result[T, RestErrorMessage] =
  if body.contentType == ApplicationJsonMediaType:
    let data =
      try:
        RestJson.decode(body.data, T,
                        requireAllFields = true,
                        allowUnknownFields = true)
      except SerializationError as exc:
        debug "Failed to decode JSON data",
              err = exc.formatMsg("<data>"),
              data = string.fromBytes(body.data)
        return err(
          RestErrorMessage.init(Http400, UnableDecodeError,
                                [exc.formatMsg("<data>")]))
      except CatchableError as exc:
        return err(
            RestErrorMessage.init(Http400, UnexpectedDecodeError, [$exc.msg]))
    ok(data)
  elif body.contentType == OctetStreamMediaType:
    let blck =
      try:
        SSZ.decode(body.data, T)
      except SerializationError as exc:
        return err(
          RestErrorMessage.init(Http400, UnableDecodeError,
                                [exc.formatMsg("<data>")]))
      except CatchableError as exc:
        return err(
            RestErrorMessage.init(Http400, UnexpectedDecodeError, [$exc.msg]))
    ok(blck)
  else:
    err(RestErrorMessage.init(Http415, "Invalid content type",
                              [$body.contentType]))

proc encodeBytes*[T: EncodeTypes](value: T,
                                  contentType: string): RestResult[seq[byte]] =
  case contentType
  of "application/json":
    let data =
      block:
        try:
          var stream = memoryOutput()
          var writer = JsonWriter[RestJson].init(stream)
          writer.writeValue(value)
          stream.getOutput(seq[byte])
        except IOError:
          return err("Input/output error")
        except SerializationError:
          return err("Serialization error")
    ok(data)
  else:
    err("Content-Type not supported")

proc encodeBytes*[T: EncodeArrays](value: T,
                                   contentType: string): RestResult[seq[byte]] =
  case contentType
  of "application/json":
    let data =
      block:
        try:
          var stream = memoryOutput()
          var writer = JsonWriter[RestJson].init(stream)
          writer.writeArray(value)
          stream.getOutput(seq[byte])
        except IOError:
          return err("Input/output error")
        except SerializationError:
          return err("Serialization error")
    ok(data)
  else:
    err("Content-Type not supported")

proc encodeBytes*[T: EncodeOctetTypes](
       value: T,
       contentType: string
     ): RestResult[seq[byte]] =
  case contentType
  of "application/json":
    let data =
      try:
        var stream = memoryOutput()
        var writer = JsonWriter[RestJson].init(stream)
        writer.writeValue(value)
        stream.getOutput(seq[byte])
      except IOError:
        return err("Input/output error")
      except SerializationError:
        return err("Serialization error")
    ok(data)
  of "application/octet-stream":
    let data =
      try:
        SSZ.encode(value)
      except CatchableError:
        return err("Serialization error")
    ok(data)
  else:
    err("Content-Type not supported")

func readSszResBytes(T: typedesc[RestBlockTypes],
                     data: openArray[byte]): RestResult[T] =
  var res: T
  try:
    readSszBytes(data, res)
    ok(res)
  except SszSizeMismatchError:
    err("Incorrect SSZ object's size")
  except SszError:
    err("Invalid SSZ object")

proc decodeBytes*[T: ProduceBlockResponseV3](
    t: typedesc[T],
    value: openArray[byte],
    contentType: Opt[ContentTypeData],
    headerConsensusVersion: string,
    headerBlinded: string,
    headerPayloadValue: string,
    headerConsensusValue: string): RestResult[T] =
  let
    mediaType =
      if contentType.isNone():
        ApplicationJsonMediaType
      else:
        if isWildCard(contentType.get().mediaType):
          return err("Incorrect Content-Type")
        contentType.get().mediaType

  if mediaType == ApplicationJsonMediaType:
    try:
      ok(RestJson.decode(value, T,
                         requireAllFields = true,
                         allowUnknownFields = true))
    except SerializationError as exc:
      debug "Failed to deserialize REST JSON data",
            err = exc.formatMsg("<data>"),
            data = string.fromBytes(value)
      return err("Serialization error")
  elif mediaType == OctetStreamMediaType:
    let
      fork = ConsensusFork.decodeString(headerConsensusVersion).valueOr:
        return err("Invalid or Unsupported consensus version")
      blinded =
        block:
          var toCheck = headerBlinded.toLowerAscii()
          if toCheck == "true":
            true
          elif toCheck == "false":
            false
          else:
            return err("Incorrect `Eth-Execution-Payload-Blinded` header value")
      executionValue =
        try:
          Opt.some parse(headerPayloadValue, UInt256, 10)
        except ValueError:
          return err("Incorrect `Eth-Execution-Payload-Value` header value")
      consensusValue =
        if len(headerConsensusValue) == 0:
          # TODO (cheatfate): We should not allow empty `consensus-value`.
          Opt.none(UInt256)
        else:
          try:
            Opt.some parse(headerConsensusValue, UInt256, 10)
          except ValueError:
            return err("Incorrect `Eth-Consensus-Block-Value` header value")
    withConsensusFork(fork):
      when consensusFork >= ConsensusFork.Deneb:
        if blinded:
          let contents =
            ? readSszResBytes(consensusFork.BlindedBlockContents, value)
          ok(
            ForkedMaybeBlindedBeaconBlock.init(
              contents, executionValue, consensusValue))
        else:
          let contents = ? readSszResBytes(consensusFork.BlockContents, value)
          ok(
            ForkedMaybeBlindedBeaconBlock.init(
              contents, executionValue, consensusValue))
      elif consensusFork >= ConsensusFork.Bellatrix:
        if blinded:
          return err("`Eth-Execution-Payload-Blinded` unsupported for " &
                     "`Eth-Consensus-Version`")
        let contents = ? readSszResBytes(consensusFork.BlockContents, value)
        ok(
          ForkedMaybeBlindedBeaconBlock.init(
            contents, executionValue, consensusValue))
      else:
        if blinded:
          return err("`Eth-Execution-Payload-Blinded` unsupported for " &
                     "`Eth-Consensus-Version`")
        let contents = ? readSszResBytes(consensusFork.BlockContents, value)
        ok(ForkedMaybeBlindedBeaconBlock.init(contents))
  else:
    err("Unsupported Content-Type")

proc decodeBytes*[T: DecodeTypes](
       t: typedesc[T],
       value: openArray[byte],
       contentType: Opt[ContentTypeData]
     ): RestResult[T] =

  let mediaType =
    if contentType.isNone():
      ApplicationJsonMediaType
    else:
      if isWildCard(contentType.get().mediaType):
        return err("Incorrect Content-Type")
      contentType.get().mediaType

  if mediaType == ApplicationJsonMediaType:
    try:
      ok RestJson.decode(value, T,
                         requireAllFields = true,
                         allowUnknownFields = true)
    except SerializationError as exc:
      debug "Failed to deserialize REST JSON data",
            err = exc.formatMsg("<data>"),
            data = string.fromBytes(value)
      err("Serialization error")
  else:
    err("Content-Type not supported")

func encodeString*(value: string): RestResult[string] =
  ok(value)

func encodeString*(
    value:
      uint64 |
      SyncCommitteePeriod |
      Epoch |
      Slot |
      CommitteeIndex |
      SyncSubcommitteeIndex): RestResult[string] =
  ok(Base10.toString(uint64(value)))

func encodeString*(value: ValidatorSig): RestResult[string] =
  ok(hexOriginal(toRaw(value)))

func encodeString*(value: GraffitiBytes): RestResult[string] =
  ok(hexOriginal(distinctBase(value)))

func encodeString*(value: Eth2Digest): RestResult[string] =
  ok(hexOriginal(value.data))

func encodeString*(value: ValidatorIdent): RestResult[string] =
  case value.kind
  of ValidatorQueryKind.Index:
    ok(Base10.toString(uint64(value.index)))
  of ValidatorQueryKind.Key:
    ok(hexOriginal(toRaw(value.key)))

func encodeString*(value: ValidatorPubKey): RestResult[string] =
  ok(hexOriginal(toRaw(value)))

func encodeString*(value: StateIdent): RestResult[string] =
  case value.kind
  of StateQueryKind.Slot:
    ok(Base10.toString(uint64(value.slot)))
  of StateQueryKind.Root:
    ok(hexOriginal(value.root.data))
  of StateQueryKind.Named:
    case value.value
    of StateIdentType.Head:
      ok("head")
    of StateIdentType.Genesis:
      ok("genesis")
    of StateIdentType.Finalized:
      ok("finalized")
    of StateIdentType.Justified:
      ok("justified")

func encodeString*(value: BroadcastValidationType): RestResult[string] =
  case value
  of BroadcastValidationType.Gossip:
    ok("gossip")
  of BroadcastValidationType.Consensus:
    ok("consensus")
  of BroadcastValidationType.ConsensusAndEquivocation:
    ok("consensus_and_equivocation")

func encodeString*(value: BlockIdent): RestResult[string] =
  case value.kind
  of BlockQueryKind.Slot:
    ok(Base10.toString(uint64(value.slot)))
  of BlockQueryKind.Root:
    ok(hexOriginal(value.root.data))
  of BlockQueryKind.Named:
    case value.value
    of BlockIdentType.Head:
      ok("head")
    of BlockIdentType.Genesis:
      ok("genesis")
    of BlockIdentType.Finalized:
      ok("finalized")

func decodeString*(t: typedesc[PeerStateKind],
                   value: string): Result[PeerStateKind, cstring] =
  case value
  of "disconnected":
    ok(PeerStateKind.Disconnected)
  of "connecting":
    ok(PeerStateKind.Connecting)
  of "connected":
    ok(PeerStateKind.Connected)
  of "disconnecting":
    ok(PeerStateKind.Disconnecting)
  else:
    err("Incorrect peer state value")

func encodeString*(value: PeerStateKind): Result[string, cstring] =
  case value
  of PeerStateKind.Disconnected:
    ok("disconnected")
  of PeerStateKind.Connecting:
    ok("connecting")
  of PeerStateKind.Connected:
    ok("connected")
  of PeerStateKind.Disconnecting:
    ok("disconnecting")

func decodeString*(t: typedesc[PeerDirectKind],
                   value: string): Result[PeerDirectKind, cstring] =
  case value
  of "inbound":
    ok(PeerDirectKind.Inbound)
  of "outbound":
    ok(PeerDirectKind.Outbound)
  else:
    err("Incorrect peer direction value")

func encodeString*(value: PeerDirectKind): Result[string, cstring] =
  case value
  of PeerDirectKind.Inbound:
    ok("inbound")
  of PeerDirectKind.Outbound:
    ok("outbound")

func encodeString*(peerid: PeerId): Result[string, cstring] =
  ok($peerid)

func decodeString*(t: typedesc[EventTopic],
                   value: string): Result[EventTopic, cstring] =
  case value
  of "head":
    ok(EventTopic.Head)
  of "block":
    ok(EventTopic.Block)
  of "attestation":
    ok(EventTopic.Attestation)
  of "voluntary_exit":
    ok(EventTopic.VoluntaryExit)
  of "bls_to_execution_change":
    ok(EventTopic.BLSToExecutionChange)
  of "proposer_slashing":
    ok(EventTopic.ProposerSlashing)
  of "attester_slashing":
    ok(EventTopic.AttesterSlashing)
  of "blob_sidecar":
    ok(EventTopic.BlobSidecar)
  of "finalized_checkpoint":
    ok(EventTopic.FinalizedCheckpoint)
  of "chain_reorg":
    ok(EventTopic.ChainReorg)
  of "contribution_and_proof":
    ok(EventTopic.ContributionAndProof)
  of "light_client_finality_update":
    ok(EventTopic.LightClientFinalityUpdate)
  of "light_client_optimistic_update":
    ok(EventTopic.LightClientOptimisticUpdate)
  else:
    err("Incorrect event's topic value")

func encodeString*(value: set[EventTopic]): Result[string, cstring] =
  var res: string
  if EventTopic.Head in value:
    res.add("head,")
  if EventTopic.Block in value:
    res.add("block,")
  if EventTopic.Attestation in value:
    res.add("attestation,")
  if EventTopic.VoluntaryExit in value:
    res.add("voluntary_exit,")
  if EventTopic.BLSToExecutionChange in value:
    res.add("bls_to_execution_change,")
  if EventTopic.ProposerSlashing in value:
    res.add("proposer_slashing,")
  if EventTopic.AttesterSlashing in value:
    res.add("attester_slashing,")
  if EventTopic.BlobSidecar in value:
    res.add("blob_sidecar,")
  if EventTopic.FinalizedCheckpoint in value:
    res.add("finalized_checkpoint,")
  if EventTopic.ChainReorg in value:
    res.add("chain_reorg,")
  if EventTopic.ContributionAndProof in value:
    res.add("contribution_and_proof,")
  if EventTopic.LightClientFinalityUpdate in value:
    res.add("light_client_finality_update,")
  if EventTopic.LightClientOptimisticUpdate in value:
    res.add("light_client_optimistic_update,")
  if len(res) == 0:
    return err("Topics set must not be empty")
  res.setLen(len(res) - 1)
  ok(res)

func toList*(value: set[ValidatorFilterKind]): seq[string] =
  const
    pendingSet = {ValidatorFilterKind.PendingInitialized,
                  ValidatorFilterKind.PendingQueued}
    activeSet = {ValidatorFilterKind.ActiveOngoing,
                 ValidatorFilterKind.ActiveExiting,
                 ValidatorFilterKind.ActiveSlashed}
    exitedSet = {ValidatorFilterKind.ExitedUnslashed,
                 ValidatorFilterKind.ExitedSlashed}
    withdrawSet = {ValidatorFilterKind.WithdrawalPossible,
                   ValidatorFilterKind.WithdrawalDone}
  var
    res: seq[string]
    v = value

  template processSet(argSet, argName: untyped): untyped =
    if argSet * v == argSet:
      res.add(argName)
      v.excl(argSet)

  template processSingle(argSingle, argName): untyped =
    if argSingle in v:
      res.add(argName)

  processSet(pendingSet, "pending")
  processSet(activeSet, "active")
  processSet(exitedSet, "exited")
  processSet(withdrawSet, "withdrawal")
  processSingle(ValidatorFilterKind.PendingInitialized, "pending_initialized")
  processSingle(ValidatorFilterKind.PendingQueued, "pending_queued")
  processSingle(ValidatorFilterKind.ActiveOngoing, "active_ongoing")
  processSingle(ValidatorFilterKind.ActiveExiting, "active_exiting")
  processSingle(ValidatorFilterKind.ActiveSlashed, "active_slashed")
  processSingle(ValidatorFilterKind.ExitedUnslashed, "exited_unslashed")
  processSingle(ValidatorFilterKind.ExitedSlashed, "exited_slashed")
  processSingle(ValidatorFilterKind.WithdrawalPossible, "withdrawal_possible")
  processSingle(ValidatorFilterKind.WithdrawalDone, "withdrawal_done")
  res

func decodeString*(t: typedesc[ValidatorSig],
                   value: string): Result[ValidatorSig, cstring] =
  if len(value) != ValidatorSigSize + 2:
    return err("Incorrect validator signature value length")
  if value[0] != '0' and value[1] != 'x':
    return err("Incorrect validator signature encoding")
  ValidatorSig.fromHex(value)

func decodeString*(t: typedesc[ValidatorPubKey],
                   value: string): Result[ValidatorPubKey, cstring] =
  if len(value) != ValidatorKeySize + 2:
    return err("Incorrect validator's key value length")
  if value[0] != '0' and value[1] != 'x':
    err("Incorrect validator's key encoding")
  else:
    ValidatorPubKey.fromHex(value)

func decodeString*(t: typedesc[GraffitiBytes],
                   value: string): Result[GraffitiBytes, cstring] =
  try:
    ok(GraffitiBytes.init(value))
  except ValueError:
    err("Unable to decode graffiti value")

func decodeString*(t: typedesc[string],
                   value: string): Result[string, cstring] =
  ok(value)

func decodeString*(t: typedesc[Slot], value: string): Result[Slot, cstring] =
  let res = ? Base10.decode(uint64, value)
  ok(Slot(res))

func decodeString*(t: typedesc[Epoch], value: string): Result[Epoch, cstring] =
  let res = ? Base10.decode(uint64, value)
  ok(Epoch(res))

func decodeString*(t: typedesc[SyncCommitteePeriod],
                   value: string): Result[SyncCommitteePeriod, cstring] =
  let res = ? Base10.decode(uint64, value)
  ok(SyncCommitteePeriod(res))

func decodeString*(t: typedesc[uint64],
                   value: string): Result[uint64, cstring] =
  Base10.decode(uint64, value)

func decodeString*(t: typedesc[StateIdent],
                   value: string): Result[StateIdent, cstring] =
  if len(value) > 2:
    if (value[0] == '0') and (value[1] == 'x'):
      if len(value) != RootHashSize + 2:
        err("Incorrect state root value length")
      else:
        let res = ? parseRoot(value)
        ok(StateIdent(kind: StateQueryKind.Root, root: res))
    elif (value[0] in DecimalSet) and (value[1] in DecimalSet):
      let res = ? Base10.decode(uint64, value)
      ok(StateIdent(kind: StateQueryKind.Slot, slot: Slot(res)))
    else:
      case value
      of "head":
        ok(StateIdent(kind: StateQueryKind.Named,
                      value: StateIdentType.Head))
      of "genesis":
        ok(StateIdent(kind: StateQueryKind.Named,
                      value: StateIdentType.Genesis))
      of "finalized":
        ok(StateIdent(kind: StateQueryKind.Named,
                      value: StateIdentType.Finalized))
      of "justified":
        ok(StateIdent(kind: StateQueryKind.Named,
                      value: StateIdentType.Justified))
      else:
        err("Incorrect state identifier value")
  else:
    let res = ? Base10.decode(uint64, value)
    ok(StateIdent(kind: StateQueryKind.Slot, slot: Slot(res)))

func decodeString*(t: typedesc[BlockIdent],
                   value: string): Result[BlockIdent, cstring] =
  if len(value) > 2:
    if (value[0] == '0') and (value[1] == 'x'):
      if len(value) != RootHashSize + 2:
        err("Incorrect block root value length")
      else:
        let res = ? parseRoot(value)
        ok(BlockIdent(kind: BlockQueryKind.Root, root: res))
    elif (value[0] in DecimalSet) and (value[1] in DecimalSet):
      let res = ? Base10.decode(uint64, value)
      ok(BlockIdent(kind: BlockQueryKind.Slot, slot: Slot(res)))
    else:
      case value
        of "head":
          ok(BlockIdent(kind: BlockQueryKind.Named,
                        value: BlockIdentType.Head))
        of "genesis":
          ok(BlockIdent(kind: BlockQueryKind.Named,
                        value: BlockIdentType.Genesis))
        of "finalized":
          ok(BlockIdent(kind: BlockQueryKind.Named,
                        value: BlockIdentType.Finalized))
        else:
          err("Incorrect block identifier value")
  else:
    let res = ? Base10.decode(uint64, value)
    ok(BlockIdent(kind: BlockQueryKind.Slot, slot: Slot(res)))

func decodeString*(t: typedesc[BroadcastValidationType],
                   value: string): Result[BroadcastValidationType, cstring] =
  case value
  of "gossip":
    ok(BroadcastValidationType.Gossip)
  of "consensus":
    ok(BroadcastValidationType.Consensus)
  of "consensus_and_equivocation":
    ok(BroadcastValidationType.ConsensusAndEquivocation)
  else:
    err("Incorrect broadcast validation type value")

func decodeString*(t: typedesc[ValidatorIdent],
                   value: string): Result[ValidatorIdent, cstring] =
  if len(value) > 2:
    if (value[0] == '0') and (value[1] == 'x'):
      if len(value) != ValidatorKeySize + 2:
        err("Incorrect validator's key value length")
      else:
        let res = ? ValidatorPubKey.fromHex(value)
        ok(ValidatorIdent(kind: ValidatorQueryKind.Key,
                          key: res))
    elif (value[0] in DecimalSet) and (value[1] in DecimalSet):
      let res = ? Base10.decode(uint64, value)
      ok(ValidatorIdent(kind: ValidatorQueryKind.Index,
                        index: RestValidatorIndex(res)))
    else:
      err("Incorrect validator identifier value")
  else:
    let res = ? Base10.decode(uint64, value)
    ok(ValidatorIdent(kind: ValidatorQueryKind.Index,
                      index: RestValidatorIndex(res)))

func decodeString*(t: typedesc[PeerId],
                   value: string): Result[PeerId, cstring] =
  PeerId.init(value)

func decodeString*(t: typedesc[CommitteeIndex],
                   value: string): Result[CommitteeIndex, cstring] =
  let res = ? Base10.decode(uint64, value)
  CommitteeIndex.init(res)

func decodeString*(t: typedesc[SyncSubcommitteeIndex],
                   value: string): Result[SyncSubcommitteeIndex, cstring] =
  let res = ? Base10.decode(uint64, value)
  SyncSubcommitteeIndex.init(res)

func decodeString*(t: typedesc[Eth2Digest],
                   value: string): Result[Eth2Digest, cstring] =
  if len(value) != RootHashSize + 2:
    return err("Incorrect root value length")
  if value[0] != '0' and value[1] != 'x':
    return err("Incorrect root value encoding")
  parseRoot(value)

func decodeString*(t: typedesc[ValidatorFilter],
                   value: string): Result[ValidatorFilter, cstring] =
  case value
  of "pending_initialized":
    ok({ValidatorFilterKind.PendingInitialized})
  of "pending_queued":
    ok({ValidatorFilterKind.PendingQueued})
  of "active_ongoing":
    ok({ValidatorFilterKind.ActiveOngoing})
  of "active_exiting":
    ok({ValidatorFilterKind.ActiveExiting})
  of "active_slashed":
    ok({ValidatorFilterKind.ActiveSlashed})
  of "exited_unslashed":
    ok({ValidatorFilterKind.ExitedUnslashed})
  of "exited_slashed":
    ok({ValidatorFilterKind.ExitedSlashed})
  of "withdrawal_possible":
    ok({ValidatorFilterKind.WithdrawalPossible})
  of "withdrawal_done":
    ok({ValidatorFilterKind.WithdrawalDone})
  of "pending":
    ok({
      ValidatorFilterKind.PendingInitialized,
      ValidatorFilterKind.PendingQueued
    })
  of "active":
    ok({
      ValidatorFilterKind.ActiveOngoing,
      ValidatorFilterKind.ActiveExiting,
      ValidatorFilterKind.ActiveSlashed
    })
  of "exited":
    ok({
      ValidatorFilterKind.ExitedUnslashed,
      ValidatorFilterKind.ExitedSlashed
    })
  of "withdrawal":
    ok({
      ValidatorFilterKind.WithdrawalPossible,
      ValidatorFilterKind.WithdrawalDone
    })
  else:
    err("Incorrect validator state identifier value")

func decodeString*(t: typedesc[ConsensusFork],
                   value: string): Result[ConsensusFork, cstring] =
  let vres = ConsensusFork.init(toLowerAscii(value))
  if vres.isSome:
    ok(vres.get)
  else:
    err("Unsupported or invalid beacon block fork version")

proc decodeString*(t: typedesc[EventBeaconBlockObject],
                   value: string): Result[EventBeaconBlockObject, string] =
  try:
    ok(RestJson.decode(value, t,
                       requireAllFields = true,
                       allowUnknownFields = true))
  except SerializationError as exc:
    err(exc.formatMsg("<data>"))

## ValidatorIdent
proc writeValue*(w: var JsonWriter[RestJson],
                 value: ValidatorIdent) {.raises: [IOError].} =
  writeValue(w, value.encodeString().get())

proc readValue*(reader: var JsonReader[RestJson],
                value: var ValidatorIdent) {.
     raises: [IOError, SerializationError].} =
  value = decodeString(ValidatorIdent, reader.readValue(string)).valueOr:
    raise newException(SerializationError, $error)

## RestValidatorRequest
proc readValue*(reader: var JsonReader[RestJson],
                value: var RestValidatorRequest) {.
     raises: [IOError, SerializationError].} =
  var
    statuses: Opt[seq[string]]
    ids: Opt[seq[string]]

  for fieldName in readObjectFields(reader):
    case fieldName
    of "ids":
      if ids.isSome():
        reader.raiseUnexpectedField("Multiple `ids` fields found",
                                    "RestValidatorRequest")
      ids = Opt.some(reader.readValue(seq[string]))
    of "statuses":
      if statuses.isSome():
        reader.raiseUnexpectedField("Multiple `statuses` fields found",
                                    "RestValidatorRequest")
      statuses = Opt.some(reader.readValue(seq[string]))
    else:
      unrecognizedFieldWarning(fieldName, typeof(value).name)

  let
    validatorIds =
      block:
        # Test for uniqueness of value will be happened on higher layer.
        if ids.isSome():
          var res: seq[ValidatorIdent]
          for item in ids.get():
            let value = decodeString(ValidatorIdent, item).valueOr:
              reader.raiseUnexpectedValue($error)
            res.add(value)
          Opt.some(res)
        else:
          Opt.none(seq[ValidatorIdent])
    filter =
      block:
        if statuses.isSome():
          var res: ValidatorFilter
          for item in statuses.get():
            let value = decodeString(ValidatorFilter, item).valueOr:
              reader.raiseUnexpectedValue($error)
            # Test for uniqueness of value.
            if value * res != {}:
              reader.raiseUnexpectedValue(
                "The `statuses` array should consist of only unique values")
            res.incl(value)
          Opt.some(res)
        else:
          Opt.none(ValidatorFilter)

  value = RestValidatorRequest(ids: validatorIds, status: filter)

proc writeValue*(writer: var JsonWriter[RestJson],
                 value: RestValidatorRequest) {.raises: [IOError].} =
  writer.beginRecord()
  if value.ids.isSome():
    var res: seq[string]
    for item in value.ids.get():
      res.add(item.encodeString().get())
    writer.writeField("ids", res)
  if value.status.isSome():
    let res = value.status.get().toList()
    if len(res) > 0:
      writer.writeField("statuses", res)
  writer.endRecord()

## RestSyncCommitteeReward
proc writeValue*(writer: var JsonWriter[RestJson],
                 value: RestSyncCommitteeReward) {.raises: [IOError].} =
  writer.beginRecord()
  writer.writeField("validator_index", value.validator_index)
  writer.writeField("reward", value.reward)
  writer.endRecord()

## ForkedAttestation
proc readValue*(reader: var JsonReader[RestJson],
                value: var ForkedAttestation) {.
     raises: [IOError, SerializationError].} =
  var
    version: Opt[ConsensusFork]
    data: Opt[JsonString]

  for fieldName {.inject.} in readObjectFields(reader):
    case fieldName
    of "version":
      if version.isSome():
        reader.raiseUnexpectedField("Multiple version fields found",
                                    "ForkedAttestation")
      let vres = reader.readValue(string).toLowerAscii()
      version = ConsensusFork.init(vres)
      if version.isNone():
        reader.raiseUnexpectedValue("Incorrect version field value")
    of "data":
      if data.isSome():
        reader.raiseUnexpectedField(
          "Multiple '" & fieldName & "' fields found", "ForkedAttestation")
      data = Opt.some(reader.readValue(JsonString))
    else:
      unrecognizedFieldWarning(fieldName, "ForkedAttestation")

  if version.isNone():
    reader.raiseUnexpectedValue("Field `version` is missing")
  if data.isNone():
    reader.raiseUnexpectedValue("Field `data` is missing")

  withConsensusFork(version.get()):
    when consensusFork < ConsensusFork.Electra:
      let res =
        try:
          RestJson.decode(string(data.get()),
                          phase0.Attestation,
                          requireAllFields = true,
                          allowUnknownFields = true)
        except SerializationError as exc:
          reader.raiseUnexpectedValue(
            "Incorrect phase0 attestation format, [" &
            exc.formatMsg("ForkedAttestation") & "]")
      value = ForkedAttestation.init(res, consensusFork)
    else:
      let res =
        try:
          RestJson.decode(string(data.get()),
                          electra.Attestation,
                          requireAllFields = true,
                          allowUnknownFields = true)
        except SerializationError as exc:
          reader.raiseUnexpectedValue(
            "Incorrect electra attestation format, [" &
            exc.formatMsg("ForkedAttestation") & "]")
      value = ForkedAttestation.init(res, consensusFork)

## ForkedAttestation
proc writeValue*(writer: var JsonWriter[RestJson],
                 attestation: ForkedAttestation) {.raises: [IOError].} =
  writer.beginRecord()
  writer.writeField("version", attestation.kind)
  withAttestation(attestation):
    writer.writeField("data", forkyAttestation)
  writer.endRecord()
