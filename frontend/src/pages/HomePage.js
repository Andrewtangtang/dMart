import React, { useState, useEffect } from 'react';
import ProjectCard from '../components/ProjectCard';

// 獲取專案資料
const getProjects = async () => {
  return [
    {
      id: 1,
      title: '創新科技產品開發計畫',
      contractAddress: '0x1234...5678',
      image: 'https://picsum.photos/400/300',
      targetAmount: 2000,
      currentAmount: 1500
    },
    {
      id: 2,
      title: '永續時尚設計專案',
      contractAddress: '0x9876...4321',
      image: 'https://picsum.photos/400/301',
      targetAmount: 3000,
      currentAmount: 3000
    },
    {
      id: 3,
      title: '在地小農支持計畫',
      contractAddress: '0x2468...1357',
      image: 'https://picsum.photos/400/302',
      targetAmount: 5000,
      currentAmount: 4500
    }
  ];
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