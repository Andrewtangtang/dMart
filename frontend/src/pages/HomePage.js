import React, { useState, useEffect } from 'react';
import ProjectCard from '../components/ProjectCard';
import { getIPFSUrl } from '../utils/ipfs';

// 獲取專案資料
const getProjects = async () => {
  // 模擬從後端 API 獲取專案資料
  const mockProjects = [
    {
      id: 1,
      title: '永續時尚設計專案',
      contractAddress: '0x1234...5678',
      image: getIPFSUrl('bafybeidvg6xjnpsy3a7um3vmbwr73vd5ggqycshw5sowpmwb2r2evfvm3q'),
      currentAmount: 30000,
      targetAmount: 50000,
    },
    {
      id: 2,
      title: '在地小農支持計畫',
      contractAddress: '0x9876...4321',
      image: getIPFSUrl('bafkreiawyjbhm2kwm2q3ysy2ccwrc3i5l6dbupqhht4znxcdmi5m3k5lmm'),
      currentAmount: 20000,
      targetAmount: 100000,
    }
  ];

  // const allProjects = await contract.allProjects();
  // const allProjectsLength = await contract.allProjectsLength();
  // const allProjectAddresses = await Promise.all(
  //   Array.from({ length: allProjectsLength }, (_, i) => contract.allProjects(i))
  // );

  // return await Promise.all(
  //   allProjectAddresses.map(async (address, index) => {
  //     const details = await contract.projectDetails(address);
  //     return {
  //       id: index + 1,
  //       title: details.title || "no title",
  //       address: address || "no address",
  //       image: details.image || 'https://picsum.photos/400/300', // Default image
  //     };
  //   })
  // );
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