// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import './AccessControlled.sol';        // This file contains all the access controlled information

contract KYC is AccessControlled {
    // Declarations
    // Structure defined for details of customer
    struct Customer {
        bytes32 userName;           // User Name of the Customer           
        bytes32 custData;           // KYC Data of the Customer
        bool    kycStatus;          // KYC status of the customer true means verified, false means unverified
        uint    downVotes;          // Number of down votes given by the banks
        uint    upVotes;            // Number of up votes given by the banks
        address bank;               // address of the bank who has verified the customer
    }
    
    // Structure defined for bank details
    struct Bank {
        bytes32 bankName;           // Name of the bank
        address ethAddress;         // Address of the bank (Here address denotes the account address of the bank in blockchain)
        uint    report;             // Number of reports provided by the banks
        uint    kycCount;           // Number of customers Verfied by the bank
        bool    kycPermission;      // Permission for KYC - true means bank have permission, false means bank don't have permission
        bytes32 regNumber;          // Registration Number of the bank
    }
    
    // Structure defined for KYC Request
    struct KYCRequest {
        bytes32 userName;           // User Name of the customer
        address bankAddress;        // Bank address of the bank who has raised the request
        bytes32 custData;           // KYC data of the customer
    }
    
    mapping(bytes32 => Customer) customerList;          // List of all the customers (Mapping is done as customer name => customer deatils)
    mapping(address => Bank) bankList;                  // List of all the banks (Mapping is done as account address of the bank => bank details)
    mapping(bytes32 => KYCRequest[]) requestList;       // List of all the request raised (Mapping is done as customer name => array of requests raised for that customer)
    
    // Data Varaibles
    uint noOfRequest;               // Number of request raised for a particular customer         
    uint noOfAccount;               // Number of bank accounts in the system
    KYCRequest request;             // Request data to store 
    
    
    // Constructor
    // calling the parent constructor to sets the admin value and initalizing all the data variables as blank or zero
    constructor() AccessControlled(msg.sender) {
        noOfRequest = 0;
        noOfAccount = 0;
        request.userName = "";
        request.bankAddress = address(0);
        request.custData = "";
    }
    
    // Events
    
    event addRequestEvent(bytes32 CustomerUserName, bytes32 CustomerData, address AddeddBy);        // Add a Request Event
    event addCustomerEvent(bytes32 CustomerUserName, bytes32 CustomerData, address VerifiedBy);     // Add a Customer Event
    event removeRequestEvent(bytes32 CustomerUserName, bytes32 CustomerData, address RemovedBy);    // Remove a Request Event
    event removeCustomerEvent(bytes32 CustomeUserName, address RemovedBy);                          // Remove a Customer Event
    event upvoteCustomerEvent(bytes32 CustomeUserName, address UpVotedBy);                          // Upvote a Customer Event
    event downvoteCustomerEvent(bytes32 CustomeUserName, address DownVotedBy);                      // Down Vote a Customer Event
    event modifyCustomerEvent(bytes32 CustomeUserName, bytes32 ModifiedData, address ModifiedBy);   // Modify a customer Event
    event reportBankEvent(address ReportedBank, address ReportedBy);                                // Report a Bank Event
    event addBankEvent(bytes32 BankName, address BankAddress, bytes32 BankRegistrationNumber);      // Add a Bank Event
    event modifyBankKYCPermissionEvent(address KYCModifiedOf, bool KYCModifiedAs);                  // Modify a KYC Permission Event
    event removeBankEvent(address RemovedBank);                                                     // Remove a Bank Event
    
    
    // Operations
    function addRequest(bytes32 userName, bytes32 userData) 
                                                    onlyBank(msg.sender)                // Only Bank can perform 
                                                    checkBank(msg.sender, 1)            // Bank should be a registered bank
                                                    checkPermission(msg.sender)         // Bank should have KYC Permission
                                                    checkRequest(userName, userData, 2) // Request should not be present in request list
                                                    external returns(bool) {
        // Creating a request data
        request.userName = userName;            
        request.bankAddress = msg.sender;
        request.custData = userData;
        
        // Adding the request in request list
        requestList[userName].push(request);
        
        // Calling the add a request event
        emit addRequestEvent(userName, userData, msg.sender);
        return true;
    }
    
    function addCustomer(bytes32 userName, bytes32 userData)
                                                    onlyBank(msg.sender)                // Only Bank can perform 
                                                    checkBank(msg.sender, 1)            // Bank should be a registered bank
                                                    checkPermission(msg.sender)         // Bank should have KYC Permission
                                                    checkRequest(userName, userData, 1) // Request should be present in request list
                                                    checkCustomer(userName, 1)          // Customer should not already be registered
                                                    external returns(bool) {
        // Creating and adding the customer data in customer list
        customerList[userName].userName = userName;
        customerList[userName].custData = userData;
        customerList[userName].kycStatus = true;
        customerList[userName].downVotes = 0;
        customerList[userName].upVotes = 0;
        customerList[userName].bank = msg.sender;
        
        // Incrementing the KYC count of the bank
        bankList[msg.sender].kycCount += 1;

        // calling add a customer event
        emit addCustomerEvent(userName, userData, msg.sender);
        return true;
    }
    
    function removeRequest(bytes32 userName, bytes32 userData)
                                                    onlyBank(msg.sender)                // Only Bank can perform
                                                    checkBank(msg.sender, 1)            // Bank should be a registered bank
                                                    checkRequest(userName, userData, 1) // Request should be present in request list
                                                    external returns(bool) {
        // check if the request is the last request in the array for that customer then delete the last request
        if(noOfRequest == requestList[userName].length) {
            requestList[userName].pop();                
        }
        // if not then swap the last request with the request to be deleted and then delete the last request
        else {
            requestList[userName][noOfRequest - 1] = requestList[userName][requestList[userName].length - 1];
            requestList[userName].pop();
        }
        
        // Calling remove a request event
        emit removeRequestEvent(userName, userData, msg.sender);
        return true;
    }
    
    function removeCustomer(bytes32 userName) 
                                    onlyBank(msg.sender)                    // Only Bank can perform
                                    checkBank(msg.sender, 1)                // Bank should be a registered bank
                                    checkCustomer(userName, 2)              // Customer should be registered
                                    checkCustomerBank(userName, msg.sender) // Only the bank which added the customer can delete the customer
                                    external returns(bool) {
        // delete the customer from the customer list
        delete customerList[userName];
        
        // delete all the requests of that customer
        if(requestList[userName].length != 0) {
            delete requestList[userName];   
        }
        
        // calling remove a customer event
        emit removeCustomerEvent(userName, msg.sender);
        return true;
    }
    
    function viewCustomer(bytes32 userName)
                                    onlyBank(msg.sender)            // Only Bank can perform
                                    checkBank(msg.sender, 1)        // Bank should be a registered bank
                                    checkCustomer(userName, 2)      // Customer should be registered
                                    external view returns(bytes memory) {
        // return the user name and the user data of the customer
        return abi.encodePacked(customerList[userName].userName, customerList[userName].custData);
    }
    
    function upvoteCustomer(bytes32 userName)
                                    onlyBank(msg.sender)            // Only Bank can perform
                                    checkBank(msg.sender, 1)        // Bank should be a registered bank
                                    checkPermission(msg.sender)     // Bank should have KYC Permission
                                    checkCustomer(userName, 2)      // Customer should be registered
                                    external returns(bool) {
        // Increment the number of up vote count of the customer
        customerList[userName].upVotes += 1;
        
        // change the status of the customer based on the number of upvotes
        customerAuthenticity(userName);
        
        // Calling upvote a customer event
        emit upvoteCustomerEvent(userName, msg.sender);
        return true;
    }
    
    function downvoteCustomer(bytes32 userName)
                                        onlyBank(msg.sender)        // Only Bank can perform
                                        checkBank(msg.sender, 1)    // Bank should be a registered bank
                                        checkPermission(msg.sender) // Bank should have KYC Permission
                                        checkCustomer(userName, 2)  // Customer should be registered
                                        external returns(bool) {
        // Increment the number of down vote count of the customer
        customerList[userName].downVotes += 1;
        
        // change the status of the customer based on the number of downvotes
        customerAuthenticity(userName);
        
        // Calling down vote a customer event
        emit downvoteCustomerEvent(userName, msg.sender);
        return true;
    }
    
    function modifyCustomer(bytes32 userName, bytes32 userData)
                                                        onlyBank(msg.sender)                    // Only Bank can perform
                                                        checkBank(msg.sender, 1)                // Bank should be a registered bank
                                                        checkCustomer(userName, 2)              // Customer should be registered
                                                        checkCustomerData(userName, userData)   // Customer data should be different form waht stored in the list
                                                        external returns(bool) {
        // Updating the customer details also setting the number of upvote and downvotes as 0 and also changing the bank who verified the customer
        customerList[userName].custData = userData;
        customerList[userName].upVotes = 0;
        customerList[userName].downVotes = 0;
        customerList[userName].bank = msg.sender;
        
        // delete all the requests for that customer
        if(requestList[userName].length != 0){
            delete requestList[userName];
        }
        
        // Calling modify a customer event 
        emit modifyCustomerEvent(userName, userData, msg.sender);
        return true;
    }
    
    function getCustomerStatus(bytes32 userName)
                                        onlyBank(msg.sender)            // Only Bank can perform
                                        checkBank(msg.sender, 1)        // Bank should be a registered bank
                                        checkCustomer(userName, 2)      // Customer should be registered
                                        external view returns(bool) {
        // return the KYC status of the customer
        return customerList[userName].kycStatus;
    }
    
    function reportBank(address bankAddress)
                                    onlyBank(msg.sender)                        // Only Bank can perform
                                    checkBank(bankAddress, 1)                   // Bank should be a registered bank
                                    checkBank(msg.sender, 1)                    // Bank should be a registered bank
                                    checkReportSender(msg.sender, bankAddress)  // Bank cannot report itself
                                    external returns(bool) {
        // Increment the number of reports of the bank
        bankList[bankAddress].report += 1;
        
        // Update the KYC Permission of the bank on the basis of number reports
        bankAuthenticity(bankAddress);
        
        // Calling report a bank event
        emit reportBankEvent(bankAddress, msg.sender);
        return true;
    }
    
    function getBankReport(address bankAddress)
                                        onlyBank(msg.sender)            // Only Bank can perform
                                        checkBank(bankAddress, 1)       // Bank should be a registered bank
                                        checkBank(msg.sender, 1)        // Bank should be a registered bank
                                        external view returns(uint) {
        // Return the number of reports of that particular bank
        return bankList[bankAddress].report;
    }
    
    function viewBankDetails(address bankAddress)
                                        onlyBank(msg.sender)            // Only Bank can perform
                                        checkBank(bankAddress, 1)       // Bank should be a registered bank
                                        checkBank(msg.sender, 1)        // Bank should be a registered bank
                                        external view returns(Bank memory) {
        // return the bank details
        return bankList[bankAddress];
    }
    
    function addBank(bytes32 bankName, address bankAddress, bytes32 bankRegNumber)
                                                                        onlyAdmin(msg.sender)       // Only Admin can perform
                                                                        checkBank(bankAddress, 2)   // Bank should not be a registered bank
                                                                        external returns(bool) {
        // Adding the bank details and setiing the KYC count and number of reports as 0 also KYC Permission as true
        bankList[bankAddress].bankName = bankName;
        bankList[bankAddress].ethAddress = bankAddress;
        bankList[bankAddress].report = 0;
        bankList[bankAddress].kycCount = 0;
        bankList[bankAddress].kycPermission = true;
        bankList[bankAddress].regNumber = bankRegNumber;
        
        // Increment the number of account variable
        noOfAccount += 1;
        
        // Calling add a bank event
        emit addBankEvent(bankName, bankAddress, bankRegNumber);
        return true;
    }
    
    function modifyBankKYCPermission(address bankAddress)
                                                onlyAdmin(msg.sender)           // Only Admin can perform
                                                checkBank(bankAddress, 1)       // Bank should be a registered bank
                                                external returns(bool) {
        // Setting the KYC Permission of the bank as true from false or false from true.
        bankList[bankAddress].kycPermission = !bankList[bankAddress].kycPermission;
        
        // Calling modifying KYC Permission event
        emit modifyBankKYCPermissionEvent(bankAddress, bankList[bankAddress].kycPermission);
        return true;
    }
    
    function removeBank(address bankAddress)
                                    onlyAdmin(msg.sender)           // Only Admin can perform
                                    checkBank(bankAddress, 1)       // Bank should be a registered bank
                                    external returns(bool) {
        // Delete the bank from bank list
        delete bankList[bankAddress];
        
        // Calling delete a bank event
        emit removeBankEvent(bankAddress);
        return true;
    }
    
    function customerAuthenticity(bytes32 userName) internal {
        // If number of accounts are more than 5 then for any customer if number of downvotes are more than or equal to the one third of the accounts
        // then set the KYC Status of that customer as false.
        if(noOfAccount > 5) {
            if(customerList[userName].downVotes >= (noOfAccount / 3)) {
                customerList[userName].kycStatus = false;
                return;
            }
        }
        
        // If number of downvotes are greater than or equal to the number of upvotes then set the KYC status as false.
        if(customerList[userName].downVotes >= customerList[userName].upVotes) {
            customerList[userName].kycStatus = false;
            return;
        }
        // If number of upvotes is greater than the number of downvotes and number of downvotes is not more than or equal to the one third
        // of the accounts then set the KYC status as true.
        else {
            customerList[userName].kycStatus = true;  
            return;
        }
    }
    
    function bankAuthenticity(address bankAddress) internal {
        // If number of accoounts are more than 5 then for any bank if number of reports are greater than or equal to the one third of the accounts 
        // then set the KYC permission of the bank as false.
        if(noOfAccount > 5) {
            if(bankList[bankAddress].report >= (noOfAccount / 3)) {
                bankList[bankAddress].kycPermission = false;
                return;
            }
        }
    }
    
    // Modifiers
    modifier checkPermission(address _bank){
        require(bankList[_bank].kycPermission, "Bank not have KYC permission");
        _;
    }
    
    modifier checkRequest(bytes32 _name, bytes32 _data, uint funcType) {
        if(funcType == 1) {
            noOfRequest = requestList[_name].length;
            require(noOfRequest != 0, "No request has been raised for this customer");   
        }
        noOfRequest = 0;
        for(uint i = 0; i < requestList[_name].length; i++) {
            if(requestList[_name][i].custData == _data) {
                noOfRequest = i + 1;
                break;
            }
        }
        if(funcType == 1){
            require(noOfRequest != 0, "Request of the Customer for this data is not requested");
        }
        else if(funcType == 2){
            require(noOfRequest == 0, "Request already raised for this customer and data");
        }
        _;
    }
    
    modifier checkCustomer(bytes32 _name, uint funcType) {
        if(funcType == 1) {
            require(customerList[_name].userName != _name, "Customer is already registered");
        }
        else if(funcType == 2) {
            require(customerList[_name].userName == _name, "Customer is not registered");
        }
        _;
    }
    
    modifier checkCustomerBank(bytes32 _name, address _bank) {
        require(customerList[_name].bank == _bank, "Customer is not verfied by you");
        _;
    }
    
    modifier checkCustomerData(bytes32 _name, bytes32 _data) {
        require(customerList[_name].userName == _name && customerList[_name].custData != _data, 
                "Customer is already having this data. No modification needed");
        _;
    }
    
    modifier checkBank(address _bank, uint funcType) {
        if(funcType == 1) {
            require(bankList[_bank].ethAddress == _bank, "Bank address is invalid or Bank is not added by admin");
        }
        else if(funcType == 2) {
            require(bankList[_bank].ethAddress != _bank, "Bank address is already added");
        }
        _;
    }
    
    modifier checkReportSender(address _sender, address _bank) {
        require(_sender != _bank, "You can't report to yourself");
        _;
    }
}