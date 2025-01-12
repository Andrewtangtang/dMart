import React from 'react';
import { useNavigate } from 'react-router-dom';

const ProjectCard = ({ title, contractAddress, image, progress }) => {
  const navigate = useNavigate();

  const handleClick = () => {
    navigate(`/project/${contractAddress}`);
  };

  return (
    <div 
      className="bg-white rounded-lg overflow-hidden shadow-sm hover:shadow-md transition-shadow cursor-pointer"
      onClick={handleClick}
    >
      <div className="relative pb-[60%]">
        <img
          src={image}
          alt={title}
          className="absolute top-0 left-0 w-full h-full object-cover"
        />
      </div>
      <div className="p-3">
        <h3 className="text-base font-medium mb-1.5 line-clamp-2">{title}</h3>
        <p className="text-gray-500 text-sm mb-2.5">Contract Address: {contractAddress}</p>
        
        {/* Progress Bar */}
        <div className="relative">
          <div className="flex mb-1.5 items-center justify-between">
            <div>
              <span className="text-xs font-medium inline-block py-1 px-2 rounded-full text-[#00AA9F] bg-[#00AA9F]/10">
                募資進度
              </span>
            </div>
            <div className="text-right">
              <span className="text-sm font-medium inline-block text-[#00AA9F]">
                {progress}%
              </span>
            </div>
          </div>
          <div className="overflow-hidden h-2 mb-1 text-xs flex rounded bg-[#00AA9F]/10">
            <div
              style={{ width: `${progress}%` }}
              className="shadow-none flex flex-col text-center whitespace-nowrap text-white justify-center bg-[#00AA9F]"
            ></div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ProjectCard; 