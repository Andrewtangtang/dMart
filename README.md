# Dapp_G1

## Frontend

### 1. Set up


```
cd frontend
yarn install
```
---

### 2. Create .env
```
touch .env
```

type this in ```.env```
```
REACT_APP_INFURA_PROJECT_ID=10311d634e48456eb1a692b8952d47eb
REACT_APP_FACTORY_ADDRESS=0x8E3BfcfC9385A3159877a93f02F1C340136Ee9B7
```

### 3. Run Frontend

```
yarn start
```


## Backend

### 1. Set up


```
cd backend/src
forge install
forge install OpenZeppelin/openzeppelin-contracts --no-commit
```
---

### 2. Test Function

```
forge test --mc ContractName --mt FunctionName
```

Optinal: If you encounter any issues with package linking, run
```
forge remappings
```



## Contract Structure
```
src
  /interfaces
      IDMartCallee.sol               // Standard DMart user interface
      IDMartERC20.sol               // Standard ERC20 interface
      IDMartERC721.sol               // Standard ERC721 interface
      IDMartFactory.sol    // Interface for the DMart Factory contract
      IDMartPool.sol       // Interface for the DMart Pool contract
  /contracts
      DMartFactory.sol     // Factory contract for creating projects
      DMartPool.sol        // Pool contract for managing liquidity pools
      DMartERC20.sol               // Standard ERC20 contract
      DMartERC721.sol               // Standard ERC721 contract
  /test
      DMartTest.t.sol        // Test suite for the DMart contracts

```



## Functions
### get project details
| Name                  | Function                                   |
|-----------------------|-------------------------------------------|
| getFundraisingTarget  | Retrieve the fundraising target for the project. |
| getRaisedAmount       | Retrieve the amount of funds raised.      |
| getPhase              | Retrieve the current phase of the project.|

---

### get project operations
| Name                 | Function                                 |
|----------------------|------------------------------------------|
| createProject        | Create a new project.                   |
| updateProject        | Update the details of an existing project. |
| endProject           | End or close the project.               |

---

### mint project tokens
| Name                  | Function                                 |
|-----------------------|------------------------------------------|
| mintProjectToken      | Mint new tokens for the project.        |
| mintProjectNFT        | Mint NFTs associated with the project.  |

---

### interact with lending protocol
| Name                         | Function                            |
|------------------------------|-------------------------------------|
| transferToLendingProtocol    | Transfer funds to the lending protocol. |
| transferFromLendingProtocol  | Retrieve funds from the lending protocol. |

---

### interact with snapshot voting
| Name               | Function                                 |
|--------------------|------------------------------------------|
| createVoting       | Create a new voting session.            |
| getVotingResult    | Retrieve the results of a voting session.|
