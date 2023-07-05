// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.16;
import "openzeppelin/utils/Strings.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import {OperatorFeeModuleBase} from "../ModuleBase.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {INotaModule} from "../interfaces/INotaModule.sol";
import {INotaRegistrar} from "../interfaces/INotaRegistrar.sol";

/**
 * @notice Contract: stores invoice structs, allows freelancer/client to set work status'
 * 1) Milestone invoice is created
    a) if the caller is the owner, caller is the worker.
    b) if the caller isn't the owner, caller is the client.
        i) ensure that the first milestone amount is escrowed or instant sent (increment if instant as the upfront)
 * 2) Work is done
 * 3) Cashing is executed
    a) if the caller is the owner, they are trying to cash the milestone
 * Releasing a milestone requires the funder to escrow the next milestone
 * Disputation is not supported
 * Transfers are not supported
 * The funder can cash the escrowed milestone, if remaining, which revokes the invoice until it's escrowed again.
 * IDEA: could add make each milestone a ReversibleTimelock
 * QUESTION: should worker need to claim the milestones manually? (for now)
 * QUESTION: Should client only be allowed to fund one milestone at a time? (for now)
Milestone example
Write:
Invoice({ startTime:0, currentMilestone:0, totalMilestones:3, isRevoked:false })
 Requested - [10][20][30]
 Escrowed  - [00][00][00]


Fund:
Invoice({ startTime:now, currentMilestone:0, totalMilestones:3, isRevoked:false }) {worker starts job}
 Requested - [10][20][30]
 Escrowed  - [10][00][00]


Cash (disallowed since cashingMilestone isn't less than currentMilestone)
OR
Cash (client):
Invoice({ startTime:then, currentMilestone:0, totalMilestones:3, isRevoked:true }) {Client can take back currentMilestone}
 Requested - [10][20][30]
 Escrowed  - [00][00][00]


Fund:
Invoice({ startTime:then, currentMilestone:1, totalMilestones:3, isRevoked:false }) {first milestone was reached}
 Requested - [10][20][30]
 Escrowed  - [10][20][00]


Cash (worker):
Invoice({ startTime:then, currentMilestone:1, totalMilestones:3, isRevoked:false })
 Requested - [10][20][30]
 Escrowed  - [00][20][00]
OR
Cash (client):
Invoice({ startTime:then, currentMilestone:1, totalMilestones:3, isRevoked:true }) {Client can take back currentMilestone}
 Requested - [10][20][30]
 Escrowed  - [10][00][00]


Fund:
Invoice({ startTime:then, currentMilestone:2, totalMilestones:3, isRevoked:false }) {second milestone was reached}
 Requested - [10][20][30]
 Escrowed  - [00][20][30]


Cash (worker):
Invoice({ startTime:then, currentMilestone:2, totalMilestones:3, isRevoked:false })
 Requested - [10][20][30]
 Escrowed  - [00][00][30]
OR
Cash (client):
Invoice({ startTime:then, currentMilestone:2, totalMilestones:3, isRevoked:true }) {Client can take back currentMilestone}
 Requested - [10][20][30]
 Escrowed  - [00][20][00]


Fund:
Invoice({ startTime:then, currentMilestone:3, totalMilestones:3, isRevoked:false }) {third milestone was reached}
 Requested - [10][20][30]
 Escrowed  - [00][20][30]


 */
contract Milestones is OperatorFeeModuleBase {
    struct Milestone {
        uint256 amount;
        // bool isFunded;
        bool isCashed;
    }
    struct Invoice {
        uint256 startTime;
        uint256 currentMilestone; // currentMilestone := currently funded but not released
        uint256 totalMilestones;
        address client;
        address worker;
        bytes32 documentHash;
        bool isRevoked; // Happens when client revokes the currentMilestone's escrow
    }
    mapping(uint256 => Invoice) public invoices;
    mapping(uint256 => Milestone[]) public milestones;

    error OnlyOwner();
    error OnlyClient();
    error Disallowed();
    error AddressZero();
    error WrongAmount();
    error NotFundedYet();
    error AlreadyCashed();
    error WrongMilestone();
    error NotCashableYet();
    error InvoiceWithPay();
    error OnlyOwnerOrClient();
    error InstantOnlyUpfront();
    error OnlyWorkerOrClient();
    error AllMilestonesFunded();
    error OnlyOwnerOrApproved();
    error InsufficientPayment();
    error InsufficientMilestones();
    error CantDeleteCurrentMilestone();

    event Invoiced(
        uint256 notaId,
        address toNotify,
        bytes32 docHash,
        uint256[] milestoneAmounts
    );

    constructor(
        address registrar,
        DataTypes.WTFCFees memory _fees,
        string memory __baseURI
    ) OperatorFeeModuleBase(registrar, _fees) {
        _URI = __baseURI;
    }

    function processWrite(
        address caller,
        address owner,
        uint256 notaId,
        address currency,
        uint256 escrowed,
        uint256 instant,
        bytes calldata initData
    ) external override onlyRegistrar returns (uint256) {
        (
            address toNotify,
            address dappOperator,
            bytes32 docHash,
            uint256[] memory milestoneAmounts
        ) = abi.decode(initData, (address, address, bytes32, uint256[]));
        uint256 totalMilestones = milestoneAmounts.length;
        if (totalMilestones < 2) revert InsufficientMilestones();

        /// TODO optimize milestones.push() logic
        // Invoice
        if (caller == owner) {
            if (instant != 0 || escrowed != 0) revert InvoiceWithPay();
            invoices[notaId].worker = caller;
            invoices[notaId].client = toNotify;
            for (uint256 i = 0; i < totalMilestones; i++) {
                milestones[notaId].push(
                    Milestone({amount: milestoneAmounts[i], isCashed: false})
                );
            }
        }
        // Payment
        else if (toNotify == owner) {
            if (owner == address(0)) revert AddressZero();
            invoices[notaId].worker = toNotify;
            invoices[notaId].client = caller;
            invoices[notaId].startTime = block.timestamp;

            // If instant is used, that must be first milestone (upfront) and second must be funded
            if (instant == milestoneAmounts[0]) {
                if (escrowed != milestoneAmounts[1])
                    revert InsufficientPayment();

                invoices[notaId].currentMilestone += 1; // First milestone sent, second is now funded (index 1)

                milestones[notaId].push(
                    Milestone({amount: milestoneAmounts[0], isCashed: true})
                );

                for (uint256 i = 1; i < totalMilestones; i++) {
                    milestones[notaId].push(
                        Milestone({
                            amount: milestoneAmounts[i],
                            isCashed: false
                        })
                    );
                }
            }
            // Instant is not used, first milestone must be funded
            else {
                if (escrowed != milestoneAmounts[0])
                    revert InsufficientPayment();
                for (uint256 i; i < totalMilestones; i++) {
                    milestones[notaId].push(
                        Milestone({
                            amount: milestoneAmounts[i],
                            isCashed: false
                        })
                    );
                }
            }
        } else {
            revert Disallowed();
        }

        invoices[notaId].totalMilestones = totalMilestones;
        invoices[notaId].documentHash = docHash;
        emit Invoiced(notaId, toNotify, docHash, milestoneAmounts);
        return takeReturnFee(currency, escrowed + instant, dappOperator, 0);
    }

    function processTransfer(
        address caller,
        address approved,
        address owner,
        address /*from*/,
        address /*to*/,
        uint256 /*notaId*/,
        DataTypes.Nota calldata nota,
        bytes memory data
    ) external override onlyRegistrar returns (uint256) {
        if (caller != owner && caller != approved) revert OnlyOwnerOrApproved(); // Question: enable for invoice factoring?
        // revert Disallowed();
        return
            takeReturnFee(nota.currency, nota.escrowed, abi.decode(data, (address)), 1);
    }

    function processFund(
        address /*caller*/,
        address /*owner*/,
        uint256 escrowed,
        uint256 instant,
        uint256 notaId,
        DataTypes.Nota calldata nota,
        bytes calldata initData
    ) external override onlyRegistrar returns (uint256) {
        Milestone[] memory milestoneAmounts = milestones[notaId];

        if (invoices[notaId].startTime == 0) {
            /// Initial funding of an invoice (instant allowed)
            if (instant == milestones[notaId][0].amount) {
                if (escrowed != milestoneAmounts[1].amount)
                    revert InsufficientPayment();
                milestones[notaId][0].isCashed = true;
                invoices[notaId].currentMilestone += 1; // Instant and escrow used [Technically currentMilestone was -1 so increment once]
            } else if (instant == 0) {
                // Instant wasn't used
                if (escrowed != milestoneAmounts[0].amount)
                    revert InsufficientPayment();
            } else {
                revert InsufficientPayment(); // instant was wrong amount
            }
            invoices[notaId].startTime = block.timestamp;
        } else if (!invoices[notaId].isRevoked) {
            /// Not the first time it was funded
            if (instant != 0) revert InstantOnlyUpfront();

            invoices[notaId].currentMilestone += 1; // is funding the next milestone, increment so escrow check is based on next milestone

            /// If final escrow hit, no escrow necessary. Allows the last to be released
            if (
                invoices[notaId].currentMilestone !=
                invoices[notaId].totalMilestones
            ) {
                if (
                    escrowed !=
                    milestoneAmounts[invoices[notaId].currentMilestone].amount
                ) revert InsufficientPayment();
            }
        } else {
            /// Revoked being unrevoked
            if (instant != 0) revert InstantOnlyUpfront();
            if (
                escrowed !=
                milestoneAmounts[invoices[notaId].currentMilestone].amount
            ) revert InsufficientPayment();
            invoices[notaId].isRevoked = false; // Don't increment milestones- the currentMilestone escrowed amount is returned
        }

        return
            takeReturnFee(
                nota.currency,
                escrowed + instant,
                abi.decode(initData, (address)),
                2
            );
    }

    function processCash(
        address caller,
        address owner,
        address to,
        uint256 amount, // Question: This could function as the milestone index if the cashing amount was determined by the module's return value for `amount`
        uint256 notaId,
        DataTypes.Nota calldata nota,
        bytes calldata initData
    ) external override onlyRegistrar returns (uint256) {
        // Any caller can cash milestones < currentMilestone (when `to` == owner)
        (uint256 cashingMilestone, address dappOperator) = abi.decode(
            initData,
            (uint256, address)
        );
        if (invoices[notaId].startTime == 0) revert NotFundedYet();

        if (to == owner) {
            // Cashing out, must be less than current milestone
            if (cashingMilestone >= invoices[notaId].currentMilestone)
                revert NotCashableYet();
            if (milestones[notaId][cashingMilestone].isCashed)
                revert AlreadyCashed();
            if (amount != milestones[notaId][cashingMilestone].amount)
                revert WrongAmount();
            milestones[notaId][cashingMilestone].isCashed = true;
        } else if (caller == invoices[notaId].client) {
            if (cashingMilestone != invoices[notaId].currentMilestone)
                revert WrongMilestone();
            if (amount != milestones[notaId][cashingMilestone].amount)
                revert WrongAmount();
            milestones[notaId][invoices[notaId].currentMilestone]
                .isCashed = true; // Question: Should this be the case??
            invoices[notaId].isRevoked = true;
        } else {
            revert Disallowed();
        }
        return takeReturnFee(nota.currency, amount, dappOperator, 3);
    }

    function processApproval(
        address /*caller*/,
        address /*owner*/,
        address /*to*/,
        uint256 /*notaId*/,
        DataTypes.Nota calldata /*nota*/,
        bytes memory /*initDat*/
    ) external view override onlyRegistrar {
        // if (caller != owner) revert OnlyOwner(); // Question: enable for invoice factoring?
        revert Disallowed();
    }

    /// TODO should the docHash be the external site or another URI?
    function processTokenURI(
        uint256 tokenId
    ) public view override onlyRegistrar returns (string memory, string memory) {
        // require(exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        string memory __baseURI = _baseURI();

        Invoice memory invoice = invoices[tokenId];
        string memory attributes = string(abi.encodePacked(
            ',{"trait_type":"Start Time","value":', itoa(invoice.startTime), '},',
            '{"trait_type":"Current Milestone","value":', itoa(invoice.currentMilestone), '},',
            '{"trait_type":"Total Milestones","value":', itoa(invoice.totalMilestones), '},',
            '{"trait_type":"Client","value":"', Strings.toHexString(uint256(uint160(invoice.client))), '"},',
            '{"trait_type":"Worker","value":"', Strings.toHexString(uint256(uint160(invoice.worker))), '"},',
            '{"trait_type":"DocumentHash","value":"', string(abi.encodePacked(invoice.documentHash)), '"},',
            '{"trait_type":"Revoked","value":', invoice.isRevoked ? 'true' : 'false', '}'
        ));
        // TODO move Document Hash into external URL?
        if (bytes(__baseURI).length == 0) {
            return (attributes, "");
        } else {
            return (attributes, string(abi.encodePacked(',"external_url":"', _baseURI(), itoa(tokenId), '"')));
        }
    }

    function _baseURI() internal view returns (string memory) {
        return _URI;
    }

    // function setBaseURI(string calldata __baseURI) external onlyOwner {
    //     _URI = __baseURI;
    // }

    function getMilestones(
        uint256 notaId
    ) public view returns (Milestone[] memory) {
        return milestones[notaId];
    }

    // Question: Should worker be able to add/remove milestones?
    function addMilestone(uint256 notaId, uint256 amount) public {
        if (msg.sender != invoices[notaId].client) revert OnlyClient();
        milestones[notaId].push(Milestone({amount: amount, isCashed: false}));
        invoices[notaId].totalMilestones += 1;
    }

    function removeMilestone(uint256 notaId) public {
        if (msg.sender != invoices[notaId].client) revert OnlyClient();
        if (
            invoices[notaId].currentMilestone + 1 >=
            invoices[notaId].totalMilestones
        ) revert CantDeleteCurrentMilestone();
        delete milestones[notaId][invoices[notaId].totalMilestones - 1];
        invoices[notaId].totalMilestones -= 1;
    }
}

/**
FUND LOGIC SIMPLIFIED
        uint256 currentMilestone = invoices[notaId].currentMilestone; // QUESTION: Is this a pointer or a separate var? SEPARATE!

        // Initial funding of an invoice
        if (invoices[notaId].startTime == 0) {
            invoices[notaId].startTime = block.timestamp;
            // Can use instant pay on first funding.
            if (instant == milestones[notaId][currentMilestone].amount) {
                milestones[notaId][currentMilestone].isCashed = true;
                invoices[notaId].currentMilestone += 1; // escrow check comes later
                currentMilestone += 1; // QUESTION: redundant?
                // Technically currentMilestone was -1 so don't increment (zero init)
            }
        } else if (!invoices[notaId].isRevoked) {
            if (instant != 0) revert InstantOnlyUpfront();

            invoices[notaId].currentMilestone += 1; // is funding the next milestone, increment so escrow check is based on next milestone

            if (currentMilestone == invoices[notaId].totalMilestones)
                revert AllMilestonesFunded();
        } else {
            invoices[notaId].isRevoked = false;
        }
        // if isRevoked was true then don't increment milestones- the escrowed amount reverted it to not revoked
        if (escrowed != milestones[notaId][currentMilestone].amount)
            revert InsufficientPayment();
 */
