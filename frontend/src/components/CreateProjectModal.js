import React, { useState } from 'react';

const CreateProjectModal = ({ isOpen, onClose }) => {
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    image: null,
    targetAmount: '100',
    duration: '1',
    basicPlan: {
      price: '20',
      description: ''
    },
    advancedPlan: {
      price: '40',
      description: ''
    }
  });

  const [imagePreview, setImagePreview] = useState(null);

  const handleImageChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      setFormData({ ...formData, image: file });
      const reader = new FileReader();
      reader.onloadend = () => {
        setImagePreview(reader.result);
      };
      reader.readAsDataURL(file);
    }
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    // TODO: 處理表單提交邏輯
    console.log('Form submitted:', formData);
    onClose();
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg p-8 max-w-3xl w-full mx-4 max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-2xl font-bold text-gray-900">發起募資專案</h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600"
          >
            <svg className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-6">
          {/* 專案標題 */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              專案標題
            </label>
            <input
              type="text"
              value={formData.title}
              onChange={(e) => setFormData({ ...formData, title: e.target.value })}
              className="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-[#00AA9F] focus:border-[#00AA9F]"
              required
            />
          </div>

          {/* 專案介紹 */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              專案介紹
            </label>
            <textarea
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              rows="4"
              className="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-[#00AA9F] focus:border-[#00AA9F]"
              required
            />
          </div>

          {/* 專案圖片 */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              專案圖片
            </label>
            <div className="mt-1 flex justify-center px-6 pt-5 pb-6 border-2 border-gray-300 border-dashed rounded-md">
              <div className="space-y-1 text-center">
                {imagePreview ? (
                  <div className="relative">
                    <img
                      src={imagePreview}
                      alt="Preview"
                      className="mx-auto h-48 w-auto object-cover rounded-md"
                    />
                    <button
                      type="button"
                      onClick={() => {
                        setImagePreview(null);
                        setFormData({ ...formData, image: null });
                      }}
                      className="absolute top-2 right-2 bg-white rounded-full p-1 shadow-md"
                    >
                      <svg className="h-5 w-5 text-gray-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </button>
                  </div>
                ) : (
                  <>
                    <svg
                      className="mx-auto h-12 w-12 text-gray-400"
                      stroke="currentColor"
                      fill="none"
                      viewBox="0 0 48 48"
                    >
                      <path
                        d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02"
                        strokeWidth={2}
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      />
                    </svg>
                    <div className="flex text-sm text-gray-600">
                      <label className="relative cursor-pointer bg-white rounded-md font-medium text-[#00AA9F] hover:text-[#008F86] focus-within:outline-none">
                        <span>上傳圖片</span>
                        <input
                          type="file"
                          className="sr-only"
                          accept="image/*"
                          onChange={handleImageChange}
                          required
                        />
                      </label>
                    </div>
                    <p className="text-xs text-gray-500">PNG, JPG, GIF 最大 10MB</p>
                  </>
                )}
              </div>
            </div>
          </div>

          {/* 募資金額 */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              募資金額
            </label>
            <select
              value={formData.targetAmount}
              onChange={(e) => setFormData({ ...formData, targetAmount: e.target.value })}
              className="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-[#00AA9F] focus:border-[#00AA9F] mb-2"
            >
              <option value="100">100 USDT</option>
              <option value="200">200 USDT</option>
              <option value="300">300 USDT</option>
            </select>
            <p className="text-sm text-gray-600">
              需支付保證金：{(Number(formData.targetAmount) * 0.2).toFixed(2)} USDT（募資金額的20%）
            </p>
          </div>

          {/* 募資期限 */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              募資期限
            </label>
            <select
              value={formData.duration}
              onChange={(e) => setFormData({ ...formData, duration: e.target.value })}
              className="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-[#00AA9F] focus:border-[#00AA9F]"
            >
              <option value="1">1 個月</option>
              <option value="3">3 個月</option>
              <option value="6">6 個月</option>
            </select>
          </div>

          {/* 回饋方案 */}
          <div className="space-y-4">
            <h3 className="text-lg font-medium text-gray-900">回饋方案設定</h3>
            
            {/* 基本方案 */}
            <div className="border border-gray-200 rounded-md p-4">
              <h4 className="text-base font-medium text-gray-700 mb-3">基本方案 (20 USDT)</h4>
              <div className="space-y-3">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    方案內容
                  </label>
                  <textarea
                    value={formData.basicPlan.description}
                    onChange={(e) => setFormData({
                      ...formData,
                      basicPlan: { ...formData.basicPlan, description: e.target.value }
                    })}
                    rows="3"
                    className="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-[#00AA9F] focus:border-[#00AA9F]"
                    placeholder="請詳細描述此方案包含的回饋內容..."
                    required
                  />
                </div>
              </div>
            </div>

            {/* 進階方案 */}
            <div className="border border-gray-200 rounded-md p-4">
              <h4 className="text-base font-medium text-gray-700 mb-3">進階方案 (40 USDT)</h4>
              <div className="space-y-3">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    方案內容
                  </label>
                  <textarea
                    value={formData.advancedPlan.description}
                    onChange={(e) => setFormData({
                      ...formData,
                      advancedPlan: { ...formData.advancedPlan, description: e.target.value }
                    })}
                    rows="3"
                    className="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-[#00AA9F] focus:border-[#00AA9F]"
                    placeholder="請詳細描述此方案包含的回饋內容..."
                    required
                  />
                </div>
              </div>
            </div>
          </div>

          {/* 按鈕組 */}
          <div className="flex gap-4 pt-4">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 px-6 py-3 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50 transition-colors"
            >
              取消
            </button>
            <button
              type="submit"
              className="flex-1 px-6 py-3 bg-[#FFAD36] text-white rounded-md hover:bg-[#FF9D16] transition-colors"
            >
              確認發起
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default CreateProjectModal; 