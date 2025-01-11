import React, { useState, useEffect } from 'react';
import { providers, Contract } from 'ethers'; // Correct import
import abi from './FactoryAbi.json'; // Import your ABI as a JSON file

function FetchFactoryData() {
  const infuraProjectId = process.env.REACT_APP_INFURA_PROJECT_ID;
  const provider = new providers.JsonRpcProvider(`https://sepolia.infura.io/v3/${infuraProjectId}`);
  const contractAddress = process.env.REACT_APP_FACTORY_ADDRESS;

  // Initialize the contract
  const contract = new Contract(contractAddress, abi, provider);

  const [number, setNumber] = useState(null);

  // Fetch the contract data
  const getContractNumber = async () => {
    try {
      const number = await contract.retrieve(); // Assuming the contract has a 'retrieve' function
      console.log(`Contract number: ${number}`);
      setNumber(number.toString()); // Convert BigNumber to string
    } catch (error) {
      console.error('Error reading contract number:', error);
    }
  };
  
  const [addressList, setAddressList] = useState(null);
  const [title, setTitle] = useState(null);
  const [description, setDescription] = useState(null);
  const [image, setImage] = useState(null);
  const [progress, setProgess] = useState(null);

  useEffect(() => {
    getContractNumber();
  }, []);

  // fetch list
  const fetchAddressList = async () => {
    try {
      const addresses = await contract.getAddressList(); // Call the getAddressList function
      setAddressList(addresses);
    } catch (error) {
      console.error('Error fetching address list:', error);
    }
  };

  // fetch the data
  const fetchDataFromMapping = async (address) => {
    try {
      const number = await contract.number(address); // Call the mapping getter
      setFetchedNumber(number.toString());
    } catch (error) {
      console.error('Error fetching address list:', error);
    }
  };

  const fetchTitle = async (address) => {
    try {
      const title = await contract.title(address); // Call the mapping getter
      setFetchedNumber(title);
    } catch (error) {
      console.error('Error fetching address list:', error);
    }
  };

  useEffect(() => {
    fetchAddressList();
  }, []);

  useEffect(() => {
    if (addressList.length > 0) {
      fetchTitle();
    }
  }, [addressList]);

  return (
    <div>
      <h1>Contract</h1>
      <h3>title</h3>
      {title !== null ? <p>{title}</p> : <p>Loading...</p>}
      <h3>description</h3>
      {description !== null ? <p>{description}</p> : <p>Loading...</p>}
      <h3>image</h3>
      {image !== null ? <img src={image} alt="專案圖片" class="w-full h-[400px] object-cover"/> : <p>Loading...</p>}
      <h3>progress</h3>
      {progress !== null ? <p>{progress}</p> : <p>Loading...</p>}
    </div>
  );
}

export default FetchFactoryData;
