local SpatialSoftMax, parent = torch.class('cudnn.SpatialSoftMax', 'nn.Module')
local errcheck = cudnn.errcheck

function SpatialSoftMax:__init(fast)
   parent.__init(self)
   if fast then
      self.algorithm = 'CUDNN_SOFTMAX_FAST'
   else
      self.algorithm = 'CUDNN_SOFTMAX_ACCURATE'
   end
   self.mode = 'CUDNN_SOFTMAX_MODE_CHANNEL'
   self.iSize = torch.LongStorage(4):fill(0)
end

function SpatialSoftMax:createIODescriptors(input)
   local batch = true
   if input:dim() == 3 then
      input = input:view(1, input:size(1), input:size(2), input:size(3))
      batch = false
   end
   assert(input:dim() == 4 and input:isContiguous());
   if not self.iDesc or not self.oDesc or
      input:size(1) ~= self.iSize[1] or input:size(2) ~= self.iSize[2]
   or input:size(3) ~= self.iSize[3] or input:size(4) ~= self.iSize[4] then
      self.iSize = input:size()
      self.gradInput:resizeAs(input)
      self.output:resizeAs(input)
      self.iDesc = cudnn.toDescriptor(input)
      self.oDesc = cudnn.toDescriptor(self.output)
      if not batch then
         self.gradInput = self.gradInput:view(self.gradInput:size(2),
                                              self.gradInput:size(3),
                                              self.gradInput:size(4))
         self.output = self.output:view(self.output:size(2),
                                        self.output:size(3),
                                        self.output:size(4))
      end
   end
end

local one = torch.FloatTensor({1});
local zero = torch.FloatTensor({0});

function SpatialSoftMax:updateOutput(input)
   self:createIODescriptors(input)
   errcheck('cudnnSoftmaxForward',
            cudnn.handle[cutorch.getDevice()-1],
            self.algorithm, self.mode,
            one:data(),
            self.iDesc[0], input:data(),
            zero:data(),
            self.oDesc[0], self.output:data());
   return self.output
end

function SpatialSoftMax:updateGradInput(input, gradOutput)
   assert((gradOutput:dim() == 4 or gradOutput:dim() == 3)
         and gradOutput:isContiguous());
   self:createIODescriptors(input)
   errcheck('cudnnSoftmaxBackward',
            cudnn.handle[cutorch.getDevice()-1],
            self.algorithm, self.mode,
            one:data(),
            self.oDesc[0], self.output:data(),
            self.oDesc[0], gradOutput:data(),
            zero:data(),
            self.iDesc[0], self.gradInput:data());
   return self.gradInput
end
