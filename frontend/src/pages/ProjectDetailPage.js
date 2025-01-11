import React, { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import DonateModal from '../components/DonateModal';
import web3Service from '../services/web3Service';
import { getIPFSUrl } from '../utils/ipfs';

// 固定的里程碑階段描述
const MILESTONE_DESCRIPTIONS = [
  '研發規劃階段',
  '原型開發階段',
  '測試驗證階段',
  '量產準備階段'
];

// 模擬的專案資料
const MOCK_PROJECTS = {
  '1': {
    id: '1',
    title: '創新科技產品開發計畫',
    category: '科技',
    image: getIPFSUrl('bafybeidvg6xjnpsy3a7um3vmbwr73vd5ggqycshw5sowpmwb2r2evfvm3q'),
    targetAmount: 100000,
    currentAmount: 75000,
    backerCount: 200,
    endTime: '2024-02-10T00:00:00Z',
    milestone: 2,
    contractAddress: '0x1234...5678',
    description: `我們正在開發一款革命性的智能產品，結合最新的物聯網技術與人工智慧應用。
    
    這個產品將改變人們的日常生活方式，提供更智能、更便捷的使用體驗。我們的團隊擁有豐富的研發經驗，
    致力於將這個創新概念轉化為實際的產品。
    
    資金將用於：
    - 產品原型開發
    - 核心技術研發
    - 生產線建置
    - 市場推廣`,
    plans: [
      {
        id: 1,
        price: 20,
        title: '基本方案',
        description: '產品一台 + 專屬贊助者紀念品',
        estimatedDelivery: '2024-12'
      },
      {
        id: 2,
        price: 40,
        title: '進階方案',
        description: '限定版產品一台 + 專屬贊助者紀念品 + 一年延長保固',
        estimatedDelivery: '2024-12'
      }
    ]
  },
  '2': {
    id: '2',
    title: '永續時尚設計專案',
    category: '時尚',
    image: getIPFSUrl('bafybeidvg6xjnpsy3a7um3vmbwr73vd5ggqycshw5sowpmwb2r2evfvm3q'),
    targetAmount: 50000,
    currentAmount: 45000,
    backerCount: 150,
    endTime: '2024-03-15T00:00:00Z',
    milestone: 3,
    contractAddress: '0x9876...4321',
    description: `我們致力於開發環保永續的時尚產品，使用可回收材料，
    減少環境污染，為地球盡一份心力。

    資金將用於：
    - 環保材料研發
    - 設計打樣
    - 生產設備
    - 通路開發`,
    plans: [
      {
        id: 1,
        price: 20,
        title: '基本方案',
        description: '環保服飾一件 + 感謝卡',
        estimatedDelivery: '2024-09'
      },
      {
        id: 2,
        price: 40,
        title: '進階方案',
        description: '環保服飾兩件 + 限量環保袋',
        estimatedDelivery: '2024-09'
      }
    ]
  },
  '3': {
    id: '3',
    title: '在地小農支持計畫',
    category: '地方創生',
    image: getIPFSUrl('bafkreiawyjbhm2kwm2q3ysy2ccwrc3i5l6dbupqhht4znxcdmi5m3k5lmm'),
    targetAmount: 30000,
    currentAmount: 15000,
    backerCount: 80,
    endTime: '2024-04-20T00:00:00Z',
    milestone: 1,
    contractAddress: '0x2468...1357',
    description: `支持在地小農，推廣有機農業，
    建立永續的農業生態系統。

    資金將用於：
    - 有機認證
    - 包裝設計
    - 運銷通路
    - 農地改良`,
    plans: [
      {
        id: 1,
        price: 20,
        title: '基本方案',
        description: '當季有機蔬果一箱 + 小農故事集',
        estimatedDelivery: '2024-06'
      },
      {
        id: 2,
        price: 40,
        title: '進階方案',
        description: '每月有機蔬果箱 × 2期 + 小農參訪券',
        estimatedDelivery: '2024-06'
      }
    ]
  }
};

// 模擬合約存儲的參與者資料
const MOCK_CONTRACT_PARTICIPANTS = {
  '0x1234...5678': ['0xABCD...1234', '0xEFGH...5678'], // 專案合約地址: [參與者地址陣列]
  '0x9876...4321': ['0x1111...2222', '0x3333...4444'],
  '0x2468...1357': ['0x5555...6666', '0xABCD...1234']
};

// 獲取專案詳細資訊
const getProjectDetails = async (projectId) => {
  // 根據 ID 返回對應的專案資料
  const projectData = MOCK_PROJECTS[projectId];
  if (!projectData) {
    throw new Error('找不到專案資料');
  }

  try {
    // 從 IPFS 獲取描述內容
    const response = await fetch(getIPFSUrl('bafkreig5nawy5kiz5fqfg47sazbsdzvfowwjmvzqgkgvu432fbughwyp7i'));
    const description = await response.text();
    
    // 印出從 IPFS 獲取的描述內容
    console.log('從 IPFS 獲取的描述內容:', description);
    console.log('IPFS URL:', getIPFSUrl('bafkreig5nawy5kiz5fqfg47sazbsdzvfowwjmvzqgkgvu432fbughwyp7i'));
    
    // 更新專案資料中的描述
    return {
      ...projectData,
      description
    };
  } catch (error) {
    console.error('從 IPFS 獲取描述失敗:', error);
    return projectData; // 如果獲取失敗，返回原始資料
  }
};

const ProjectDetailPage = () => {
  const { id } = useParams();
  const [isBookmarked, setIsBookmarked] = useState(false);
  const [projectData, setProjectData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [activeTab, setActiveTab] = useState('description');
  const [isDonateModalOpen, setIsDonateModalOpen] = useState(false);
  const [hasParticipated, setHasParticipated] = useState(false);

  // 靜態的更新和FAQ資料
  const staticUpdates = [
    {
      id: 1,
      date: '2024/1/3',
      title: '開發進度更新',
      content: '我們已完成產品原型的第一階段開發，目前正在進行功能測試。團隊正在努力優化產品性能，確保每個細節都能達到最佳狀態。接下來我們將進入第二階段的開發，專注於...'
    },
    {
      id: 2,
      date: '2024/1/1',
      title: '專案啟動公告',
      content: '感謝各位支持者的關注！我們的專案正式啟動了。在接下來的日子裡，我們會定期發布專案的最新進展，讓大家了解開發的情況...'
    }
  ];

  const staticFaqs = [
    {
      id: 1,
      question: '預計什麼時候可以收到產品？',
      answer: '我們預計在募資結束後 6 個月內完成生產並寄出產品。我們會定期更新生產進度，讓支持者了解最新狀況。'
    },
    {
      id: 2,
      question: '產品保固期限是多久？',
      answer: '產品保固期為一年，期間內如有品質問題我們將提供免費維修服務。'
    },
    {
      id: 3,
      question: '如何追蹤專案進度？',
      answer: '我們會在專案頁面定期更新開發進度，您也可以追蹤我們的社群媒體，獲得第一手資訊。'
    }
  ];

  useEffect(() => {
    const loadProjectData = async () => {
      try {
        setLoading(true);
        const details = await getProjectDetails(id);
        setProjectData(details);

        // 檢查用戶是否參與此專案
        if (web3Service.isConnected()) {
          const userAddress = web3Service.getCurrentAccount();
          // 從模擬的合約資料中檢查用戶是否為參與者
          const projectParticipants = MOCK_CONTRACT_PARTICIPANTS[details.contractAddress] || [];
          const isParticipated = projectParticipants.includes(userAddress);
          setHasParticipated(isParticipated);
        }
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
            </div>
            <h1 className="text-3xl font-bold">{projectData.title}</h1>
          </div>

          {/* 按鈕組 - 根據參與狀態決定是否顯示 */}
          {!hasParticipated && (
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
          )}
        </div>
      </div>

      {/* 下方區塊：進度和內容 */}
      <div className="max-w-4xl mx-auto grid grid-cols-1 gap-6">
        {/* 募資進度圓環和里程碑 */}
        <div className="bg-white p-6 rounded-lg shadow-md">
          <div className="flex items-center justify-between mb-4">
            <div>
              <p className="text-gray-600">募資進度</p>
              <p className="text-2xl font-bold text-[#00AA9F]">
                {Math.round((projectData.currentAmount / projectData.targetAmount) * 100)}%
              </p>
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
                  strokeDasharray={`${Math.round((projectData.currentAmount / projectData.targetAmount) * 100)}, 100`}
                />
              </svg>
              <div className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 text-lg font-bold text-[#00AA9F]">
                {Math.round((projectData.currentAmount / projectData.targetAmount) * 100)}%
              </div>
            </div>
          </div>

          {/* 里程碑進度 */}
          <div className="mb-6">
            <div className="flex justify-between items-center mb-2">
              <p className="text-gray-600">研發里程碑</p>
              <p className="text-sm font-medium text-[#00AA9F]">
                階段 {projectData.milestone + 1}
              </p>
            </div>
            <div className="relative pt-1">
              <div className="flex mb-2 items-center justify-between gap-2">
                {[0, 1, 2, 3].map((stage) => (
                  <div
                    key={stage}
                    className={`flex-1 relative ${
                      stage <= projectData.milestone ? 'text-[#00AA9F]' : 'text-gray-400'
                    }`}
                  >
                    <div className={`h-1 ${
                      stage <= projectData.milestone ? 'bg-[#00AA9F]' : 'bg-gray-200'
                    }`}></div>
                    <div className={`absolute -top-2 ${
                      stage === 0 ? 'left-0' : stage === 3 ? 'right-0' : 'left-1/2 transform -translate-x-1/2'
                    }`}>
                      <div className={`w-4 h-4 rounded-full flex items-center justify-center text-[10px] ${
                        stage <= projectData.milestone ? 'bg-[#00AA9F]' : 'bg-gray-200'
                      }`}>
                        <span className={stage <= projectData.milestone ? 'text-white' : 'text-gray-600'}>
                          {stage + 1}
                        </span>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
              <div className="text-xs text-gray-600 mt-2">
                {MILESTONE_DESCRIPTIONS[projectData.milestone]}
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
                {staticUpdates.map(update => (
                  <div key={update.id} className="border-b pb-6">
                    <div className="flex justify-between items-center mb-2">
                      <h3 className="font-medium">{update.title}</h3>
                      <span className="text-sm text-gray-500">
                        {update.date}
                      </span>
                    </div>
                    <p className="text-gray-600">{update.content}</p>
                  </div>
                ))}
              </div>
            )}
            {activeTab === 'faq' && (
              <div className="space-y-6">
                {staticFaqs.map(faq => (
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
                    <p className="text-[#00AA9F] text-2xl font-bold">{plan.price} USDT</p>
                  </div>
                </div>
                <p className="text-gray-600 mb-4">{plan.description}</p>
                <div className="text-sm text-gray-500">
                  預計出貨時間：{plan.estimatedDelivery}
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* 贊助彈窗 */}
      <DonateModal
        isOpen={isDonateModalOpen}
        onClose={() => setIsDonateModalOpen(false)}
        projectTitle={projectData?.title}
        contractAddress={projectData?.contractAddress}
      />
    </div>
  );
};

export default ProjectDetailPage;