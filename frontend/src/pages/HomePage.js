import React, { useState, useEffect } from 'react';
import ProjectCard from '../components/ProjectCard';

// 獲取熱門募資項目
const getHotProjects = async () => {
  // TODO: 這裡將來要改為實際從智能合約獲取資料
  return [
    {
      id: 1,
      title: '創新科技產品開發計畫',
      author: '0x1234...5678',
      image: 'https://picsum.photos/400/300',
      progress: 75,
      currentAmount: 1500,
      targetAmount: 2000,
      category: '科技'
    },
    {
      id: 2,
      title: '永續時尚設計專案',
      author: '0x9876...4321',
      image: 'https://picsum.photos/400/301',
      progress: 100,
      currentAmount: 3000,
      targetAmount: 3000,
      category: '時尚'
    },
    {
      id: 3,
      title: '在地小農支持計畫',
      author: '0x2468...1357',
      image: 'https://picsum.photos/400/302',
      progress: 90,
      currentAmount: 4500,
      targetAmount: 5000,
      category: '地方創生'
    }
  ];
};

// 獲取最新募資項目
const getLatestProjects = async () => {
  // TODO: 這裡將來要改為實際從智能合約獲取資料
  return [
    {
      id: 4,
      title: '藝術展覽募資計畫',
      author: '0x1357...2468',
      image: 'https://picsum.photos/400/303',
      progress: 30,
      currentAmount: 600,
      targetAmount: 2000,
      category: '藝術'
    },
    {
      id: 5,
      title: '教育創新專案',
      author: '0x8765...4321',
      image: 'https://picsum.photos/400/304',
      progress: 45,
      currentAmount: 900,
      targetAmount: 2000,
      category: '教育'
    },
    {
      id: 6,
      title: '社區營造計畫',
      author: '0x9999...8888',
      image: 'https://picsum.photos/400/305',
      progress: 15,
      currentAmount: 300,
      targetAmount: 2000,
      category: '地方創生'
    }
  ];
};

const HomePage = () => {
  const [hotProjects, setHotProjects] = useState([]);
  const [latestProjects, setLatestProjects] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [hot, latest] = await Promise.all([
          getHotProjects(),
          getLatestProjects()
        ]);
        setHotProjects(hot);
        setLatestProjects(latest);
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
      {/* 熱門募資項目 */}
      <section className="mb-16">
        <div className="flex justify-between items-center mb-8">
          <h2 className="text-2xl font-bold">熱門募資項目</h2>
          <button className="text-[#00AA9F] hover:text-[#009990]">
            看看近期的募資人氣王
          </button>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {hotProjects.map((project) => (
            <ProjectCard key={project.id} {...project} />
          ))}
        </div>
      </section>

      {/* 最新募資項目 */}
      <section>
        <div className="flex justify-between items-center mb-8">
          <h2 className="text-2xl font-bold">最新募資項目</h2>
          <button className="text-[#00AA9F] hover:text-[#009990]">
            手刀參與新秀的誕生
          </button>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {latestProjects.map((project) => (
            <ProjectCard key={project.id} {...project} />
          ))}
        </div>
      </section>
    </div>
  );
};

export default HomePage; 