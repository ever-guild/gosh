/*	
    This file is part of Ever OS.
	
	Ever OS is free software: you can redistribute it and/or modify 
	it under the terms of the Apache License 2.0 (http://www.apache.org/licenses/)
	
	Copyright 2019-2022 (c) EverX
*/
pragma ton-solidity >=0.54.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "repository.sol";
import "goshdao.sol";

/* Root contract of gosh */
contract Gosh {
    string version = "0.0.1";
    TvmCell m_RepositoryCode;
    TvmCell m_RepositoryData;
    TvmCell m_CommitCode;
    TvmCell m_CommitData;
    TvmCell m_BlobCode;
    TvmCell m_BlobData;
    TvmCell m_WalletCode;
    TvmCell m_WalletData;
    TvmCell m_codeSnapshot;
    TvmCell m_dataSnapshot;
    TvmCell m_codeDao;
    TvmCell m_dataDao;
    TvmCell m_codeTag;
    TvmCell m_dataTag;

    modifier onlyOwner {
        require(msg.pubkey() == tvm.pubkey(), 500);
        _;
    }

    constructor() public {
        tvm.accept();
    }

    function _composeRepoStateInit(string name) internal view returns(TvmCell) {
        TvmCell deployCode = GoshLib.buildRepositoryCode(
            m_RepositoryCode, address(this), name, version
        );
        return tvm.buildStateInit(deployCode, m_RepositoryData);
    }

    function deployRepository(uint256 pubkey, string name, address goshdao) public view {
        require(msg.value > 3 ton, 100);
        require(pubkey > 0, 101);
        tvm.accept();
        TvmCell s1 = _composeRepoStateInit(name);
        new Repository {stateInit: s1, value: 0.4 ton, wid: 0}(
            pubkey, name, goshdao, m_CommitCode, m_CommitData, m_BlobCode, m_BlobData, m_codeSnapshot, m_dataSnapshot, m_WalletCode, m_WalletData, m_codeTag, m_dataTag);
    }
    
    function _composeDaoStateInit(string name) internal view returns(TvmCell) {
        TvmBuilder b;
        b.store(address(this));
        b.store(name);
        b.store(version);
        TvmCell deployCode = tvm.setCodeSalt(m_codeDao, b.toCell());
        return tvm.buildStateInit(deployCode, m_dataDao);
    }
    
    function deployDao(string name, uint256 root_pubkey) public view {
        require(msg.value > 3 ton, 100);
        require(root_pubkey > 0, 101);
        tvm.accept();
        TvmCell s1 = _composeDaoStateInit(name);
        new GoshDao {stateInit: s1, value: 0.4 ton, wid: 0}(
            address(this), root_pubkey, name, m_CommitCode, m_CommitData, m_BlobCode, m_BlobData, m_RepositoryCode, m_RepositoryData, m_WalletCode, m_WalletData);
    }

    //Setters

    function setRepository(TvmCell code, TvmCell data) public  onlyOwner {
        tvm.accept();
        m_RepositoryCode = code;
        m_RepositoryData = data;
    }

    function setCommit(TvmCell code, TvmCell data) public  onlyOwner {
        tvm.accept();
        m_CommitCode = code;
        m_CommitData = data;
    }

    function setBlob(TvmCell code, TvmCell data) public  onlyOwner {
        tvm.accept();
        m_BlobCode = code;
        m_BlobData = data;
    }

    function setSnapshot(TvmCell code, TvmCell data) public  onlyOwner {
        tvm.accept();
        m_codeSnapshot = code;
        m_dataSnapshot = data;
    }
    
    function setWallet(TvmCell code, TvmCell data) public  onlyOwner {
        tvm.accept();
        m_WalletCode = code;
        m_WalletData = data;
    }
    
    function setDao(TvmCell code, TvmCell data) public  onlyOwner {
        tvm.accept();
        m_codeDao = code;
        m_dataDao = data;
    }
    
    function setTag(TvmCell code, TvmCell data) public  onlyOwner {
        tvm.accept();
        m_codeTag = code;
        m_dataTag = data;
    }

    //Getters

    function getAddrRepository(string name) external view returns(address) {
        TvmCell s1 = _composeRepoStateInit(name);
        return address.makeAddrStd(0, tvm.hash(s1));
    }
    
    function getAddrDao(string name) external view returns(address) {
        TvmCell s1 = _composeDaoStateInit(name);
        return address.makeAddrStd(0, tvm.hash(s1));
    }

    function getRepositoryCode() external view returns(TvmCell) {
        return m_RepositoryCode;
    }

    function getCommitCode() external view returns(TvmCell) {
        return m_CommitCode;
    }

    function getBlobCode() external view returns(TvmCell) {
        return m_BlobCode;
    }
}
