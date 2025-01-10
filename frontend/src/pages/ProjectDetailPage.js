import React, { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import DonateModal from '../components/DonateModal';

// 獲取專案募資時間軸數據
const getProjectTimelineData = async (projectId) => {
  // TODO: 這裡將來要改為實際從智能合約獲取資料
  return [
    { day: '0', amount: 0 },
    { day: '5', amount: 25000 },
    { day: '10', amount: 50000 },
    { day: '15', amount: 75000 },
    { day: '20', amount: 100000 },
  ];
};

// 獲取專案詳細資訊
const getProjectDetails = async (projectId) => {
  // TODO: 這裡將來要改為實際從智能合約獲取資料
  return {
    id: projectId,
    title: '創新科技產品開發計畫',
    category: '科技',
    image: 'https://picsum.photos/800/600',
    author: {
      address: '0x1234...5678',
      name: 'John Doe',
      avatar: 'https://picsum.photos/50/50',
      description: '資深產品開發者，擁有多年硬體研發經驗。專注於創新科技產品的開發與實現，致力於將創新想法轉化為實際產品。'
    },
    targetAmount: 100000,
    currentAmount: 75000,
    backerCount: 200,
    endTime: '2024-02-10T00:00:00Z',
    status: 'active', // 'active' | 'ended'
    progress: 75,
    description: `我們正在開發一款革命性的智能產品，結合最新的物聯網技術與人工智慧應用。
    
    這個產品將改變人們的日常生活方式，提供更智能、更便捷的使用體驗。我們的團隊擁有豐富的研發經驗，
    致力於將這個創新概念轉化為實際的產品。
    
    資金將用於：
    - 產品原型開發
    - 核心技術研發
    - 生產線建置
    - 市場推廣`,
    
    updates: [
      {
        id: 1,
        date: '2024-01-03',
        title: '開發進度更新',
        content: '我們已完成產品原型的第一階段開發，目前正在進行功能測試...'
      }
    ],
    
    faqs: [
      {
        id: 1,
        question: '預計什麼時候可以收到產品？',
        answer: '我們預計在募資結束後 6 個月內完成生產並寄出產品。'
      },
      {
        id: 2,
        question: '產品保固期限是多久？',
        answer: '產品保固期為一年，期間內如有品質問題我們將提供免費維修服務。'
      }
    ],
    
    plans: [
      {
        id: 1,
        price: 1000,
        title: '超早鳥專案',
        description: '產品一台 + 專屬贊助者紀念品',
        limitedQuantity: 100,
        remainingQuantity: 50,
        estimatedDelivery: '2024-12'
      },
      {
        id: 2,
        price: 2000,
        title: '限定版專案',
        description: '限定版產品一台 + 專屬贊助者紀念品 + 一年延長保固',
        limitedQuantity: 50,
        remainingQuantity: 25,
        estimatedDelivery: '2024-12'
      }
    ]
  };
};

const ProjectDetailPage = () => {
  const { id } = useParams();
  const [isBookmarked, setIsBookmarked] = useState(false);
  const [projectData, setProjectData] = useState(null);
  const [timelineData, setTimelineData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [activeTab, setActiveTab] = useState('description');
  const [isDonateModalOpen, setIsDonateModalOpen] = useState(false);

  useEffect(() => {
    const loadProjectData = async () => {
      try {
        setLoading(true);
        const [details, timeline] = await Promise.all([
          getProjectDetails(id),
          getProjectTimelineData(id)
        ]);
        setProjectData(details);
        setTimelineData(timeline);
      } catch (err) {
        setError(err.message);
        console.error('獲取專案資料失敗:', err);
      } finally {
        setLoading(false);
      }
    };

    loadProjectData();
  }, [id]);

  if (loading) {
    return (
      <div className="container mx-auto px-8 py-12 text-center">
        <p>載入中...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="container mx-auto px-8 py-12 text-center text-red-600">
        <p>錯誤：{error}</p>
      </div>
    );
  }

  if (!projectData) {
    return (
      <div className="container mx-auto px-8 py-12 text-center">
        <p>找不到專案資料</p>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-8 py-12">
      {/* 上方區塊：圖片、標題和按鈕 */}
      <div className="mb-8">
        <div className="max-w-2xl mx-auto">
          {/* 專案圖片 */}
          <div className="rounded-lg overflow-hidden shadow-lg mb-6">
            <img
              src={projectData.image}
              alt={projectData.title}
              className="w-full h-[400px] object-cover"
            />
          </div>

          {/* 標籤和標題 */}
          <div className="mb-6">
            <div className="flex items-center gap-4 mb-2">
              <span className="inline-block bg-[#00AA9F]/10 text-[#00AA9F] px-3 py-1 rounded-full text-sm">
                #{projectData.category}
              </span>
              <span className="text-gray-500 text-sm">
                提案人：{projectData.author.name}
              </span>
            </div>
            <h1 className="text-3xl font-bold">{projectData.title}</h1>
          </div>

          {/* 按鈕組 */}
          <div className="flex gap-4">
            <button 
              className="flex-1 bg-[#FFAD36] text-white py-3 rounded-md hover:bg-[#FF9D16] transition-colors text-lg font-medium"
              onClick={() => setIsDonateModalOpen(true)}
            >
              贊助專案
            </button>
            <button 
              className={`w-16 rounded-md border-2 transition-colors flex items-center justify-center
                ${isBookmarked 
                  ? 'bg-[#00AA9F] border-[#00AA9F] text-white' 
                  : 'border-gray-300 text-gray-400 hover:border-[#00AA9F] hover:text-[#00AA9F]'}`}
              onClick={() => setIsBookmarked(!isBookmarked)}
            >
              <svg 
                xmlns="http://www.w3.org/2000/svg" 
                className="h-6 w-6" 
                fill={isBookmarked ? "currentColor" : "none"}
                viewBox="0 0 24 24" 
                stroke="currentColor" 
                strokeWidth={2}
              >
                <path 
                  strokeLinecap="round" 
                  strokeLinejoin="round" 
                  d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z" 
                />
              </svg>
            </button>
          </div>
        </div>
      </div>

      {/* 下方區塊：進度和圖表 */}
      <div className="max-w-4xl mx-auto grid grid-cols-1 gap-6">
        {/* 募資進度圓環 */}
        <div className="bg-white p-6 rounded-lg shadow-md">
          <div className="flex items-center justify-between mb-4">
            <div>
              <p className="text-gray-600">募資進度</p>
              <p className="text-2xl font-bold text-[#00AA9F]">{projectData.progress}%</p>
            </div>
            <div className="w-24 h-24 relative">
              <svg className="w-full h-full" viewBox="0 0 36 36">
                <path
                  d="M18 2.0845
                    a 15.9155 15.9155 0 0 1 0 31.831
                    a 15.9155 15.9155 0 0 1 0 -31.831"
                  fill="none"
                  stroke="#E5E7EB"
                  strokeWidth="3"
                />
                <path
                  d="M18 2.0845
                    a 15.9155 15.9155 0 0 1 0 31.831
                    a 15.9155 15.9155 0 0 1 0 -31.831"
                  fill="none"
                  stroke="#00AA9F"
                  strokeWidth="3"
                  strokeDasharray={`${projectData.progress}, 100`}
                />
              </svg>
              <div className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 text-lg font-bold text-[#00AA9F]">
                {projectData.progress}%
              </div>
            </div>
          </div>
          <div className="space-y-2">
            <div className="flex justify-between">
              <span className="text-gray-600">目標金額</span>
              <span className="font-medium">{projectData.targetAmount.toLocaleString()} USDT</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">已募金額</span>
              <span className="font-medium text-[#00AA9F]">{projectData.currentAmount.toLocaleString()} USDT</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">結束時間</span>
              <span className="font-medium">{new Date(projectData.endTime).toLocaleDateString()}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">贊助人數</span>
              <span className="font-medium">{projectData.backerCount.toLocaleString()} 人</span>
            </div>
          </div>
        </div>

        {/* 募資時間軸圖表 */}
        <div className="bg-white p-6 rounded-lg shadow-md">
          <h3 className="text-lg font-medium mb-4">募資時間軸</h3>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={timelineData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="day" />
                <YAxis />
                <Tooltip />
                <Area 
                  type="monotone" 
                  dataKey="amount" 
                  stroke="#00AA9F" 
                  fill="#00AA9F" 
                  fillOpacity={0.1}
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* 內容分頁 */}
        <div className="bg-white rounded-lg shadow-md overflow-hidden">
          <div className="flex border-b">
            <button
              className={`flex-1 py-3 px-4 text-center font-medium transition-colors
                ${activeTab === 'description' 
                  ? 'text-[#00AA9F] border-b-2 border-[#00AA9F]' 
                  : 'text-gray-500 hover:text-[#00AA9F]'}`}
              onClick={() => setActiveTab('description')}
            >
              專案內容
            </button>
            <button
              className={`flex-1 py-3 px-4 text-center font-medium transition-colors
                ${activeTab === 'updates' 
                  ? 'text-[#00AA9F] border-b-2 border-[#00AA9F]' 
                  : 'text-gray-500 hover:text-[#00AA9F]'}`}
              onClick={() => setActiveTab('updates')}
            >
              專案更新
            </button>
            <button
              className={`flex-1 py-3 px-4 text-center font-medium transition-colors
                ${activeTab === 'faq' 
                  ? 'text-[#00AA9F] border-b-2 border-[#00AA9F]' 
                  : 'text-gray-500 hover:text-[#00AA9F]'}`}
              onClick={() => setActiveTab('faq')}
            >
              常見問題
            </button>
          </div>

          <div className="p-8">
            {activeTab === 'description' && (
              <div className="prose max-w-none">
                <p className="text-gray-600 leading-relaxed whitespace-pre-line">
                  {projectData.description}
                </p>
              </div>
            )}
            {activeTab === 'updates' && (
              <div className="space-y-6">
                {projectData.updates.map(update => (
                  <div key={update.id} className="border-b pb-6">
                    <div className="flex justify-between items-center mb-2">
                      <h3 className="font-medium">{update.title}</h3>
                      <span className="text-sm text-gray-500">
                        {new Date(update.date).toLocaleDateString()}
                      </span>
                    </div>
                    <p className="text-gray-600">{update.content}</p>
                  </div>
                ))}
              </div>
            )}
            {activeTab === 'faq' && (
              <div className="space-y-6">
                {projectData.faqs.map(faq => (
                  <div key={faq.id} className="border-b pb-6">
                    <h3 className="font-medium mb-2">{faq.question}</h3>
                    <p className="text-gray-600">{faq.answer}</p>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* 回饋方案列表 */}
        <div className="space-y-4">
          <h2 className="text-2xl font-bold">回饋方案</h2>
          <div className="grid gap-4">
            {projectData.plans.map(plan => (
              <div key={plan.id} className="bg-white p-6 rounded-lg shadow-md hover:shadow-lg transition-shadow cursor-pointer">
                <div className="flex justify-between items-start mb-4">
                  <div>
                    <h3 className="text-xl font-medium mb-2">{plan.title}</h3>
                    <p className="text-[#00AA9F] text-2xl font-bold">{plan.price.toLocaleString()} USDT</p>
                  </div>
                  <span className="text-gray-500">
                    剩餘 {plan.remainingQuantity}/{plan.limitedQuantity}
                  </span>
                </div>
                <p className="text-gray-600 mb-4">{plan.description}</p>
                <div className="text-sm text-gray-500">
                  預計出貨時間：{plan.estimatedDelivery}
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* 提案人資訊 */}
        <div className="bg-white p-6 rounded-lg shadow-md">
          <div className="flex items-center gap-4 mb-4">
            <img
              src={projectData.author.avatar}
              alt={projectData.author.name}
              className="w-12 h-12 rounded-full"
            />
            <div>
              <h3 className="font-medium">{projectData.author.name}</h3>
              <p className="text-gray-500 text-sm">{projectData.author.address}</p>
            </div>
          </div>
          <p className="text-gray-600">
            {projectData.author.description}
          </p>
        </div>
      </div>

      {/* 贊助彈窗 */}
      <DonateModal
        isOpen={isDonateModalOpen}
        onClose={() => setIsDonateModalOpen(false)}
        projectTitle={projectData?.title}
      />
    </div>
  );
};

export default ProjectDetailPage;