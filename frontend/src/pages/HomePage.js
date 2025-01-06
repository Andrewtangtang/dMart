import React from 'react';
import ProjectCard from '../components/ProjectCard';
import { mockProjects } from '../data/mockData';

const HomePage = () => {
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
          {mockProjects.slice(0, 3).map((project) => (
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
          {mockProjects.slice(3).map((project) => (
            <ProjectCard key={project.id} {...project} />
          ))}
        </div>
      </section>
    </div>
  );
};

export default HomePage; 