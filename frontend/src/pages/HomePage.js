import React, { useState, useEffect } from 'react';
import ProjectCard from '../components/ProjectCard';
import { providers, Contract } from 'ethers';
import { FactoryAbi } from "../data/FactoryAbi.json";
import { ProjectAbi } from "../data/ProjectAbi.json";
import { getIPFSUrl } from '../utils/ipfs';

// 獲取專案資料
const getProjects = async () => {
  const infuraProjectId = process.env.REACT_APP_INFURA_PROJECT_ID;
  const provider = new providers.JsonRpcProvider(`https://sepolia.infura.io/v3/${infuraProjectId}`);
  const factoryAddress = process.env.REACT_APP_FACTORY_ADDRESS;
  const factory = new Contract(factoryAddress, FactoryAbi, provider);
  
  const allProjects = await factory.allProjects(); // Assuming this returns an array of all project addresses

  // Fetch details for all projects in parallel
  return await Promise.all(
    allProjects.map(async (address, index) => {
      const project = new ethers.Contract(address, ProjectAbi, provider); // Initialize the project contract

      // Fetch project details in parallel
      const [title, image, target, totalRaised] = await Promise.all([
        project.title().catch(() => "no title"), // Get title or default
        project.image().catch(() => null), // Get image or default
        project.target().catch(() => 0), // Get target amount or default
        project.totalRaised().catch(() => 0) // Get total raised or default
      ]);

      const resolvedImage = image ? getIPFSUrl(image) : 'https://picsum.photos/400/300';

      // Return the enriched project object
      return {
        id: index + 1, // Unique ID based on index
        title,
        contractAddress: address,
        image: resolvedImage,
        targetAmount: target.toString(), // Convert BigNumber to string
        currentAmount: totalRaised.toString() // Convert BigNumber to string
      };
    })
  );
};

const HomePage = () => {
  const [projects, setProjects] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const data = await getProjects();
        // 計算每個專案的進度
        const projectsWithProgress = data.map(project => ({
          ...project,
          progress: Math.round((project.currentAmount / project.targetAmount) * 100)
        }));
        setProjects(projectsWithProgress);
      } catch (error) {
        console.error('獲取專案資料失敗:', error);
      } finally {
        setIsLoading(false);
      }
    };

    fetchData();
  }, []);

  if (isLoading) {
    return (
      <div className="container mx-auto px-8 py-12 text-center">
        <p>載入中...</p>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-8 py-12">
      <section>
        <h2 className="text-2xl font-bold mb-8">募資項目列表</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {projects.map((project) => (
            <ProjectCard key={project.id} {...project} />
          ))}
        </div>
      </section>
    </div>
  );
};

export default HomePage; 