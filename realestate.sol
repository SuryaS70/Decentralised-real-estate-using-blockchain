pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;

contract RealEstate {
  
  struct ApprovedUser {
    uint id;
    string name;
    uint districtCode;
    address pAddress;
    uint propertyCount;
    uint aadharNumber;
    bool acceptanceStatus;
  }

  struct Property {
    uint id;
    uint districtId;
    string districtName;
    uint parts;
    address owner;
    uint ownerId;
    uint areaSq;
    uint surveyNumber;
    bool acceptanceStatus;
    // bool isUnderTransfer;
    // bool newOwnerAccepted;
    // bool registrarAccepted;
  }

  struct ApprovedDistrict {
    uint districtId;
    string districtName;
    string stateName;
    uint districtCode;
    uint propertyCount;
    bool registrarFlag;
  }

  struct ApprovedRegistrar {
    uint id;
    string registrarName;
    address registrarAddress;
    uint aadharNumber;
    bool acceptanceStatus;
    uint districtCode;
  }

  mapping(uint => Property) public props;
  mapping(uint => ApprovedUser) public users;
  mapping(uint => ApprovedRegistrar) public registrars;
  mapping(uint => ApprovedDistrict) public districts;

  mapping(address => bool) public isRegistrarAddress;
  mapping(uint => bool) public isRegistrarId;

  mapping(address => bool) public isUserAddress;
  mapping(uint => bool) public isUserId;

  mapping(uint => bool) public isDistrictCode;  
  mapping(uint => uint) public districtCodeToDistrictId;

  mapping(uint => uint) public districtToRegistrar;

  mapping(uint => bool) public isPropRegistered;  //surveynumber check
  mapping(uint => mapping (uint => address)) public newOwner;

  mapping(address => bool) public pendingRegistrarReq;
  mapping(address => bool) public pendingUserReq;

  mapping(address => uint) public userAddressToUserId;
  mapping(address => uint) public regAddressToRegId;

  mapping(uint => mapping (uint => address[])) public propertyOwners;
  mapping(uint => mapping (uint => uint)) public propertyTransfers;

  mapping (uint => mapping (uint => address)) public propPartOwners;

  mapping (uint => mapping (uint => bool)) public isUnderTransfer;
  mapping (uint => mapping (uint => bool)) public registrarAccepted;
  mapping (uint => mapping (uint => bool)) public newOwnerAccepted;


  uint public nextPropId = 1;
  uint public nextRegistrarId = 1;
  uint public nextUserId = 1;
  uint public nextDistrictId = 1;

  address public admin;
  
  constructor() public {
    admin = msg.sender;
  }
  
  function addNewDistrict(string memory _districtName, string memory _stateName, uint _districtCode) public onlyAdmin(){
    require(isDistrictCode[_districtCode] == false, 'district already taken');

    districts[nextDistrictId] = ApprovedDistrict(
        nextDistrictId,
        _districtName,
        _stateName,
        _districtCode,
        0,
        false
        );

    isDistrictCode[_districtCode] = true;
    districtCodeToDistrictId[_districtCode] = nextDistrictId;
    nextDistrictId++;
  }

  function registerProperty(uint _districtId, uint _areaSq, uint _surveyNumber, uint _parts) public {
    require(isPropRegistered[_surveyNumber] == false, 'prop already registered');
    uint userId = userAddressToUserId[msg.sender];
    ApprovedDistrict memory _district = districts[_districtId];
    props[nextPropId] = Property(
        nextPropId,
        _districtId,
        _district.districtName,
        _parts,
        msg.sender,
        userId,
        _areaSq,
        _surveyNumber,
        false
        );
    
    nextPropId++;    
    
  }

  function approveProperty(uint _propId) public onlyRegistrar{
    Property storage prop = props[_propId];
    ApprovedDistrict storage district = districts[prop.districtId];

    require(prop.acceptanceStatus == false, 'already accepted');
    uint registrarId = districtToRegistrar[prop.districtId];
    ApprovedRegistrar memory registrar = registrars[registrarId];

    require(msg.sender == registrar.registrarAddress);
    prop.acceptanceStatus = true;
    isPropRegistered[prop.surveyNumber] = true;
    district.propertyCount++;
    uint _parts = prop.parts;
    for(uint i=1; i<=_parts; i++){
        propPartOwners[_propId][i] = prop.owner;
        propertyOwners[_propId][i].push(prop.owner);
        propertyTransfers[_propId][i] = 0;
    }
  }

  function initiateTransfer(uint _propId, uint _partId, address _newOwner) public{
    Property storage prop = props[_propId];
    require(isUnderTransfer[_propId][_partId] == false, 'transfer initiated already');
    // require(prop.owner == msg.sender, 'owner can only initiate transfer');
    require(propPartOwners[_propId][_partId] == msg.sender, 'owner can only initiate transfer');

    require(prop.acceptanceStatus == true, 'prop not verified yet');
    require(isUserAddress[_newOwner] == true, 'not a verified user');

    isUnderTransfer[_propId][_partId] = true;
    newOwner[_propId][_partId] = _newOwner;
  }

  function acceptTransferRegistrar(uint _propId, uint _partId) public {
    Property storage prop = props[_propId];
    require(isUnderTransfer[_propId][_partId] == true, 'transfer has not been initiated');
    address newOwnerAddress = newOwner[_propId][_partId];
    uint registrarId = districtToRegistrar[prop.districtId];
    ApprovedRegistrar memory registrar = registrars[registrarId];

    require(msg.sender == registrar.registrarAddress);
    require(registrarAccepted[_propId][_partId] == false, 'already signed');
    registrarAccepted[_propId][_partId] = true;
  
    if(registrarAccepted[_propId][_partId] && newOwnerAccepted[_propId][_partId]){
    //   prop.owner = newOwnerAddress;
      isUnderTransfer[_propId][_partId] = false;
      registrarAccepted[_propId][_partId] = false;
      newOwnerAccepted[_propId][_partId] = false;
      newOwner[_propId][_partId] = address(0);
      propertyOwners[_propId][_partId].push(newOwnerAddress);
      propertyTransfers[_propId][_partId]++;
      propPartOwners[_propId][_partId] = newOwnerAddress;
    }
  }

  function acceptTransferNewOwner(uint _propId, uint _partId) public{
    Property storage prop = props[_propId];
    require(isUnderTransfer[_propId][_partId] == true, 'transfer has not been initiated');
    address newOwnerAddress = newOwner[_propId][_partId];

    require(msg.sender == newOwnerAddress);
    require(newOwnerAccepted[_propId][_partId] == false, 'already signed');
    newOwnerAccepted[_propId][_partId] = true;
    

    if(registrarAccepted[_propId][_partId] && newOwnerAccepted[_propId][_partId]){
    //   prop.owner = newOwnerAddress;
      isUnderTransfer[_propId][_partId] = false;
      registrarAccepted[_propId][_partId] = false;
      newOwnerAccepted[_propId][_partId] = false;
      newOwner[_propId][_partId] = address(0);
      propertyOwners[_propId][_partId].push(newOwnerAddress);
      propertyTransfers[_propId][_partId]++;
      propPartOwners[_propId][_partId] = newOwnerAddress;

    }
  }

  function registrarProposal(string memory _name, uint _districtCode, uint aadharNumber) public {
    require(isRegistrarAddress[msg.sender] == false, 'already a registrar');
    require(isRegistrarId[aadharNumber] == false, 'already a registrar');
    require(pendingRegistrarReq[msg.sender] == false);

    uint districtId = districtCodeToDistrictId[_districtCode];
    ApprovedDistrict memory district = districts[districtId];
    require(district.registrarFlag == false, 'already has registrar');

    registrars[nextRegistrarId] = ApprovedRegistrar(
        nextRegistrarId,
        _name,
        msg.sender,
        aadharNumber,
        false,
        _districtCode
        );
    pendingRegistrarReq[msg.sender] = true;
    regAddressToRegId[msg.sender] = nextRegistrarId;
    nextRegistrarId++;
  }

  function approveRegistrar(uint _id) public onlyAdmin(){
    ApprovedRegistrar storage _registrar = registrars[_id];
    require(_registrar.acceptanceStatus == false, 'already approved');

    _registrar.acceptanceStatus = true;
    uint _districtId = districtCodeToDistrictId[_registrar.districtCode];
    ApprovedDistrict storage _district = districts[_districtId];

    require(_district.registrarFlag == false);

    isRegistrarAddress[_registrar.registrarAddress] = true;
    isRegistrarId[_registrar.aadharNumber] = true;
    pendingRegistrarReq[_registrar.registrarAddress] = false;

    _district.registrarFlag = true;
    districtToRegistrar[_districtId] = _id;
  }

  // function assignDistrictToRegistrar(uint _districtId, uint _registratId) public onlyAdmin{
  //   ApprovedDistrict storage _district = districts[_districtId];
  //   require(_district.registrarFlag == false);
  //   districtToRegistrar[_districtId] = _registratId;
  //   _district.registrarFlag = true;

  // }

  function userProposal(string memory _name , uint _districtCode, uint _aadharNumber) public {
    require(isUserAddress[msg.sender] == false, 'already an user');
    require(isUserId[_aadharNumber] == false, 'already an user');
    require(pendingUserReq[msg.sender] == false);
    users[nextUserId] = ApprovedUser(
        nextUserId,
        _name,
        _districtCode,
        msg.sender,
        0,
        _aadharNumber,
        false
        );
    pendingUserReq[msg.sender] = true;
    userAddressToUserId[msg.sender] = nextUserId;
    nextUserId++;
  }

  function approveUser(uint _id) public onlyRegistrar(){
    ApprovedUser storage _user = users[_id];
    require(_user.acceptanceStatus == false, 'already approved');

    _user.acceptanceStatus = true;

    isUserAddress[_user.pAddress] = true;
    isUserId[_user.aadharNumber] = true;
    pendingUserReq[_user.pAddress] = false;
  }

  modifier onlyAdmin() {
    require(msg.sender == admin, 'only admin');
    _;
  }

  modifier onlyRegistrar() {
    require(isRegistrarAddress[msg.sender] == true, 'only registrar');
    _;
  }

}


