import React, { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import DonateModal from '../components/DonateModal';

// 模擬數據
const mockTimeData = [
  { day: '0', amount: 0 },
  { day: '5', amount: 25000 },
  { day: '10', amount: 50000 },
  { day: '15', amount: 75000 },
  { day: '20', amount: 100000 },
];

// 後端 API 串接函數（待實現）
const fetchProjectData = async (projectId) => {
  // TODO: 實現與後端的 API 串接
  // return await fetch(`/api/projects/${projectId}`).then(res => res.json());
  return {
    id: projectId,
    title: '募資商品名稱',
    category: '設計',
    image: 'https://picsum.photos/800/600',
    creator: {
      name: 'Author Name',
      avatar: 'https://picsum.photos/50/50',
      description: '創作者簡介...'
    },
    targetAmount: 100000,
    currentAmount: 75000,
    backerCount: 200,
    remainingDays: 3,
    progress: 75,
    description: '專案詳細描述...',
    updates: [
      { date: '2024-01-03', content: '專案更新內容...' }
    ],
    faqs: [
      { question: '常見問題...', answer: '回答內容...' }
    ],
    rewards: [
      {
        id: 1,
        amount: 1000,
        title: '回饋方案 A',
        description: '回饋內容描述...',
        limitedQuantity: 100,
        remainingQuantity: 50,
        estimatedDelivery: '2024-12'
      }
    ]
  };
};

const ProjectDetailPage = () => {
  const { id } = useParams(); // 從 URL 獲取專案 ID
  const [isBookmarked, setIsBookmarked] = useState(false);
  const [projectData, setProjectData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [selectedReward, setSelectedReward] = useState(null);
  const [activeTab, setActiveTab] = useState('description'); // 'description' | 'updates' | 'faq'
  const [isDonateModalOpen, setIsDonateModalOpen] = useState(false);

  // 數據讀取邏輯（待啟用）
  useEffect(() => {
    // const loadProjectData = async () => {
    //   try {
    //     setLoading(true);
    //     const data = await fetchProjectData(id);
    //     setProjectData(data);
    //   } catch (err) {
    //     setError(err.message);
    //   } finally {
    //     setLoading(false);
    //   }
    // };
    // loadProjectData();
  }, [id]);

  return (
    <div className="container mx-auto px-8 py-12">
      {/* 上方區塊：圖片、標題和按鈕 */}
      <div className="mb-8">
        <div className="max-w-2xl mx-auto">
          {/* 專案圖片 */}
          <div className="rounded-lg overflow-hidden shadow-lg mb-6">
            <img
              src="https://picsum.photos/800/600"
              alt="專案圖片"
              className="w-full h-[400px] object-cover"
            />
          </div>

          {/* 標籤和標題 */}
          <div className="mb-6">
            <div className="flex items-center gap-4 mb-2">
              <span className="inline-block bg-[#00AA9F]/10 text-[#00AA9F] px-3 py-1 rounded-full text-sm">
                #設計
              </span>
              <span className="text-gray-500 text-sm">
                提案人：Author Name
              </span>
            </div>
            <h1 className="text-3xl font-bold">募資商品名稱</h1>
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
              <p className="text-2xl font-bold text-[#00AA9F]">75%</p>
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
                  strokeDasharray="75, 100"
                />
              </svg>
              <div className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 text-lg font-bold text-[#00AA9F]">
                75%
              </div>
            </div>
          </div>
          <div className="space-y-2">
            <div className="flex justify-between">
              <span className="text-gray-600">目標金額</span>
              <span className="font-medium">100,000 ETH</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">已募金額</span>
              <span className="font-medium text-[#00AA9F]">75,000 ETH</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">剩餘時間</span>
              <span className="font-medium">3 天</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">贊助人數</span>
              <span className="font-medium">200 人</span>
            </div>
          </div>
        </div>

        {/* 募資時間軸圖表 */}
        <div className="bg-white p-6 rounded-lg shadow-md">
          <h3 className="text-lg font-medium mb-4">募資時間軸</h3>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={mockTimeData}>
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
                <p className="text-gray-600 leading-relaxed">
                  dMart 是一個去中心化的群眾募資平台，我們致力於為創作者和支持者建立一個安全、透明的募資環境。透過區塊鏈技術，我們確保每一筆贊助都被完整記錄且無法竄改，讓創作者能夠專注於實現夢想，而支持者也能安心參與支持喜愛的專案。
                </p>
                <p className="text-gray-600 leading-relaxed mt-4">
                  在這裡，每個專案都代表著一個獨特的創意和夢想。我們提供完整的專案展示功能，包括詳細的專案說明、募資進度追蹤、更新動態分享等。同時，智能合約的應用確保資金的安全管理，只有在達到專案目標時，資金才會轉給創作者，為雙方提供最大的保障。
                </p>
                <p className="text-gray-600 leading-relaxed mt-4">
                  加入 dMart，成為實現夢想的一份子。無論您是懷抱創意的創作者，還是願意支持創意的贊助者，都能在這裡找到屬於自己的位置。讓我們一起，用區塊鏈技術的創新，為創意募資開啟新的可能。
                </p>
              </div>
            )}
            {activeTab === 'updates' && (
              <div className="space-y-6">
                <div className="border-b pb-6">
                  <div className="flex justify-between items-center mb-2">
                    <h3 className="font-medium">最新進度報告</h3>
                    <span className="text-sm text-gray-500">2024-01-03</span>
                  </div>
                  <p className="text-gray-600">專案最新進度更新內容...</p>
                </div>
              </div>
            )}
            {activeTab === 'faq' && (
              <div className="space-y-6">
                <div className="border-b pb-6">
                  <h3 className="font-medium mb-2">常見問題 1</h3>
                  <p className="text-gray-600">問題回答內容...</p>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* 回饋方案列表 */}
        <div className="space-y-4">
          <h2 className="text-2xl font-bold">回饋方案</h2>
          <div className="grid gap-4">
            <div className="bg-white p-6 rounded-lg shadow-md hover:shadow-lg transition-shadow cursor-pointer">
              <div className="flex justify-between items-start mb-4">
                <div>
                  <h3 className="text-xl font-medium mb-2">回饋方案 A</h3>
                  <p className="text-[#00AA9F] text-2xl font-bold">1,000 ETH</p>
                </div>
                <span className="text-gray-500">剩餘 50/100</span>
              </div>
              <p className="text-gray-600 mb-4">回饋內容描述...</p>
              <div className="text-sm text-gray-500">
                預計出貨時間：2024 年 12 月
              </div>
            </div>
          </div>
        </div>

        {/* 提案人資訊 */}
        <div className="bg-white p-6 rounded-lg shadow-md">
          <div className="flex items-center gap-4 mb-4">
            <img
              src="https://picsum.photos/50/50"
              alt="提案人頭像"
              className="w-12 h-12 rounded-full"
            />
            <div>
              <h3 className="font-medium">Author Name</h3>
              <p className="text-gray-500 text-sm">提案人</p>
            </div>
          </div>
          <p className="text-gray-600">
            創作者簡介...
          </p>
        </div>
      </div>

      {/* 贊助彈窗 */}
      <DonateModal
        isOpen={isDonateModalOpen}
        onClose={() => setIsDonateModalOpen(false)}
        projectTitle="募資商品名稱"
      />
    </div>
  );
};

export default ProjectDetailPage;